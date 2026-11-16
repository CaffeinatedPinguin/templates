#!/usr/bin/env bash
# Applies the safe standard to every repository from config.env. Idempotent:
# safe to run repeatedly; it overwrites drift.
#
#   bin/apply.sh --dry-run        # show what it would do, change nothing
#   bin/apply.sh                  # all repositories from config.env
#   bin/apply.sh project-a        # only the given repositories
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) ARGS+=("$a") ;;
  esac
done
require_tools
if ((${#ARGS[@]})); then mapfile -t TARGETS < <(printf '%s\n' "${ARGS[@]}")
else mapfile -t TARGETS < <(list_repos); fi
((${#TARGETS[@]})) || die "no repositories to process"

repo_settings() {
  sed "s/__DISCUSSIONS__/$DISCUSSIONS/" <<'JSON' | api PATCH "repos/$1" --input - >/dev/null
{
  "has_wiki": false,
  "has_discussions": __DISCUSSIONS__,
  "allow_squash_merge": true,
  "allow_merge_commit": false,
  "allow_rebase_merge": false,
  "allow_auto_merge": true,
  "allow_update_branch": true,
  "delete_branch_on_merge": true,
  "squash_merge_commit_title": "PR_TITLE",
  "squash_merge_commit_message": "PR_BODY",
  "web_commit_signoff_required": false,
  "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}
JSON
}

actions_policy() {
  api PUT "repos/$1/actions/permissions" --input - >/dev/null <<'JSON'
{ "enabled": true, "allowed_actions": "selected", "sha_pinning_required": true }
JSON
  # GitHub-owned actions plus an explicit allowlist of pinned external actions and
  # shared workflows from the templates repository, built from ACTION_PATTERNS.
  local patterns="" p sep=""
  for p in "${ACTION_PATTERNS[@]}"; do
    patterns+="$sep\"$p\""
    sep=", "
  done
  printf '{"github_owned_allowed": true, "verified_allowed": false, "patterns_allowed": [%s]}\n' "$patterns" |
    api PUT "repos/$1/actions/permissions/selected-actions" --input - >/dev/null
  api PUT "repos/$1/actions/permissions/workflow" --input - >/dev/null <<'JSON'
{ "default_workflow_permissions": "read", "can_approve_pull_request_reviews": false }
JSON
}

fork_policy() {
  printf '{"approval_policy":"%s"}' "$FORK_PR_APPROVAL" |
    api PUT "repos/$1/actions/permissions/fork-pr-contributor-approval" --input - >/dev/null
}

codeql() {
  # 422 = no supported language -> not a critical error
  printf '{"state":"configured","query_suite":"default"}' |
    api PATCH "repos/$1/code-scanning/default-setup" --input - >/dev/null
}

upsert_ruleset() { # upsert_ruleset OWNER/REPO file.json
  local repo=$1 file=$2 name id body
  body=$(sed "s/__CI_CHECK__/$CI_CHECK/" "$file")
  if [[ "$file" == *main.json && "$REQUIRE_SIGNED" == 1 ]]; then
    body=$(printf '%s' "$body" | sed 's/"rules": \[/"rules": [ { "type": "required_signatures" },/')
  fi
  name=$(printf '%s' "$body" | grep -m1 '"name"' | sed 's/.*"name": *"\([^"]*\)".*/\1/')
  id=$(ruleset_id "$repo" "$name")
  if [[ -n "$id" ]]; then printf '%s' "$body" | api PUT "repos/$repo/rulesets/$id" --input - >/dev/null
  else printf '%s' "$body" | api POST "repos/$repo/rulesets" --input - >/dev/null; fi
}

sync_labels() {
  local repo=$1 name color desc existing want=()
  existing=$(gh label list -R "$repo" --limit 300 --json name --jq '.[].name')
  while IFS=$'\t' read -r name color desc; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    want+=("$name")
    if [[ "$DRY" == 1 ]]; then dim "[dry-run] label $name"
    else gh label create "$name" -R "$repo" --color "$color" --description "$desc" --force >/dev/null; fi
  done < "$ROOT/labels.tsv"
  [[ "$PRUNE_LABELS" == 1 ]] || return 0
  local l w keep
  while IFS= read -r l; do
    [[ -z "$l" ]] && continue
    keep=0; for w in "${want[@]}"; do [[ "$l" == "$w" ]] && keep=1; done
    ((keep)) && continue
    if [[ "$DRY" == 1 ]]; then dim "[dry-run] delete label '$l'"
    else gh label delete "$l" -R "$repo" --yes >/dev/null; fi
  done <<<"$existing"
}

for name in "${TARGETS[@]}"; do
  R="$OWNER/$name"
  echo; echo "== $R $([[ $DRY == 1 ]] && echo '(dry-run)')"
  step "repository settings: squash-only, auto-merge, auto-delete branches, no wiki, discussions=$DISCUSSIONS, secret scanning + push protection" repo_settings "$R"
  step "Dependabot alerts"                     api PUT "repos/$R/vulnerability-alerts"
  step "Dependabot security updates"           api PUT "repos/$R/automated-security-fixes"
  step "private vulnerability reporting"       api PUT "repos/$R/private-vulnerability-reporting"
  step "Actions: GitHub-owned actions plus allowlist, SHA pinning, read-only token, Actions cannot approve PRs" actions_policy "$R"
  step "workflows from forks: approval ($FORK_PR_APPROVAL)" fork_policy "$R"
  if [[ "$CODEQL" == 1 ]]; then
    step "CodeQL default setup (422 = unsupported language, safe to ignore)" codeql "$R"
  fi
  if [[ "$MAIN_RULESET" == 1 ]]; then
    step "main ruleset: PR required, squash, linear, check '$CI_CHECK', block force-push/deletion" upsert_ruleset "$R" "$ROOT/rulesets/main.json"
  else
    warn "main ruleset (baseline-main) not applied: set MAIN_RULESET=1 in config.env after the first PR is merged"
  fi
  step "tag ruleset v*: no deletion or move"   upsert_ruleset "$R" "$ROOT/rulesets/tags.json"
  if [[ "$BRANCH_RULESET" == 1 ]]; then
    step "branch-name ruleset (Enterprise; on Free CI enforces it)" upsert_ruleset "$R" "$ROOT/rulesets/branch-names.json"
  fi
  step "labels from labels.tsv"                sync_labels "$R"
  warn "MANUAL (no API): https://github.com/$R/settings"
  dim  "Pull requests -> 'Collaborators only' (issues stay open to everyone)"
  dim  "Settings -> Releases -> Enable release immutability"
done

echo
if ((FAILS)); then printf '\033[31mErrors: %s\033[0m (details above). Run bin/audit.sh.\n' "$FAILS"; exit 1
else printf '\033[32mOK\033[0m\n'; fi
