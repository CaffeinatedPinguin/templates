#!/usr/bin/env bash
# Checks (read-only) whether repositories follow the standard. Changes nothing.
#   bin/audit.sh              # all repositories from config.env
#   bin/audit.sh project-a    # selected repositories
# Exit code 0 = everything OK. Suitable for an AI/hook weekly run.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_tools
if (($#)); then TARGETS=("$@"); else mapfile -t TARGETS < <(list_repos); fi

expect() { # expect DESCRIPTION ACTUAL EXPECTED
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (got: '${2:-missing}', want: '$3')"; fi
}
has_file() { gh api "repos/$1/contents/$2" --silent >/dev/null 2>&1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
GLOBAL_SECURITY=0
has_file "$OWNER/.github" SECURITY.md && GLOBAL_SECURITY=1

for name in "${TARGETS[@]}"; do
  R="$OWNER/$name"; echo; echo "== $R"
  s=$(gh api "repos/$R" --jq '[.allow_squash_merge,.allow_merge_commit,.allow_rebase_merge,.allow_auto_merge,.delete_branch_on_merge,.squash_merge_commit_title,.has_wiki,.has_discussions,(.security_and_analysis.secret_scanning.status//"?"),(.security_and_analysis.secret_scanning_push_protection.status//"?"),(.security_and_analysis.dependabot_security_updates.status//"?"),.visibility] | map(tostring) | join(" ")')
  read -r sq mc rb am dbm sqt wiki disc ss pp dsu vis <<<"$s"
  expect "public"                    "$vis" "public"
  expect "squash enabled"            "$sq"  "true"
  expect "merge commit disabled"     "$mc"  "false"
  expect "rebase merge disabled"     "$rb"  "false"
  expect "auto-merge"                "$am"  "true"
  expect "auto-delete branches"      "$dbm" "true"
  expect "squash title = PR title"   "$sqt" "PR_TITLE"
  expect "wiki disabled"             "$wiki" "false"
  expect "Discussions = $DISCUSSIONS" "$disc" "$DISCUSSIONS"
  expect "secret scanning"           "$ss"  "enabled"
  expect "push protection"           "$pp"  "enabled"
  expect "Dependabot security updates" "$dsu" "enabled"
  gh api "repos/$R/vulnerability-alerts" --silent >/dev/null 2>&1 && ok "Dependabot alerts" || bad "Dependabot alerts"
  expect "private vulnerability reporting" "$(gh api "repos/$R/private-vulnerability-reporting" --jq .enabled 2>/dev/null)" "true"
  dim "release immutability: enable manually in Settings -> Releases (no API)"
  cq=$(gh api "repos/$R/code-scanning/default-setup" --jq .state 2>/dev/null || true)
  if [[ "$cq" == configured ]]; then ok "CodeQL"; else warn "CodeQL: ${cq:-missing} (OK if the repository has no supported language)"; fi
  expect "Actions: allowed_actions" "$(gh api "repos/$R/actions/permissions" --jq .allowed_actions 2>/dev/null)" "selected"
  expect "Actions: SHA pinning required" "$(gh api "repos/$R/actions/permissions" --jq .sha_pinning_required 2>/dev/null)" "true"
  expect "Actions: GitHub-owned actions plus allowlist" "$(gh api "repos/$R/actions/permissions/selected-actions" --jq '[.github_owned_allowed,.verified_allowed]|map(tostring)|join(",")' 2>/dev/null)" "true,false"
  actual_patterns=$(gh api "repos/$R/actions/permissions/selected-actions" --jq '.patterns_allowed[]' 2>/dev/null | sort || true)
  want_patterns=$(printf '%s\n' "${ACTION_PATTERNS[@]}" | sort)
  expect "Actions: patterns_allowed" "$actual_patterns" "$want_patterns"
  expect "token read-only by default" "$(gh api "repos/$R/actions/permissions/workflow" --jq .default_workflow_permissions 2>/dev/null)" "read"
  expect "Actions cannot approve PRs" "$(gh api "repos/$R/actions/permissions/workflow" --jq .can_approve_pull_request_reviews 2>/dev/null)" "false"
  expect "workflows from forks" "$(gh api "repos/$R/actions/permissions/fork-pr-contributor-approval" --jq .approval_policy 2>/dev/null)" "$FORK_PR_APPROVAL"
  rulesets=(baseline-tags)
  if [[ "$MAIN_RULESET" == 1 ]]; then
    rulesets=(baseline-main baseline-tags)
  else
    warn "ruleset baseline-main not checked: MAIN_RULESET=0 (staging)"
  fi
  if [[ "$BRANCH_RULESET" == 1 ]]; then rulesets+=(baseline-branch-names); fi
  for rs in "${rulesets[@]}"; do
    id=$(ruleset_id "$R" "$rs")
    if [[ -z "$id" ]]; then
      if [[ $rs == baseline-branch-names ]]; then warn "ruleset $rs missing (CI enforces branch names)"; else bad "ruleset $rs missing"; fi
    else expect "ruleset $rs active" "$(gh api "repos/$R/rulesets/$id" --jq .enforcement)" "active"; fi
  done
  for f in README.md LICENSE .github/workflows/ci.yml .github/workflows/stale.yml .github/workflows/pr-labels.yml; do
    if has_file "$R" "$f"; then ok "file $f"
    elif [[ $f == LICENSE ]] && { has_file "$R" LICENSE.md || has_file "$R" LICENSE.txt; }; then ok "file LICENSE"
    else bad "missing file $f"; fi
  done
  if has_file "$R" SECURITY.md || has_file "$R" .github/SECURITY.md || ((GLOBAL_SECURITY)); then ok "SECURITY.md"; else bad "missing SECURITY.md (not in $OWNER/.github either)"; fi
  # Lint the workflows from the default branch
  mkdir -p "$TMP/$name"
  wf=$(gh api "repos/$R/contents/.github/workflows" --jq '.[] | select(.type=="file") | .path' 2>/dev/null || true)
  for p in $wf; do
    gh api "repos/$R/contents/$p" --jq .content | tr -d '\n' | base64 -d >"$TMP/$name/$(basename "$p")" 2>/dev/null || true
  done
  if [[ -n "$wf" ]]; then
    if out=$("$ROOT/bin/lint-workflows.sh" "$TMP/$name"/*); then ok "workflows: no known problems"
    else bad "workflows:"; printf '%s\n' "$out" | sed "s#$TMP/$name/##"; fi
  fi
  dim "Not checkable via API: Settings -> Pull requests = 'Collaborators only'"
done

echo
if ((FAILS)); then printf '\033[31mDeviations: %s\033[0m -> bin/apply.sh fixes settings, bin/sync-files.sh fixes files\n' "$FAILS"; exit 1
else printf '\033[32mEverything matches the standard\033[0m\n'; fi
