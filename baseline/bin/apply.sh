#!/usr/bin/env bash
# Applies the safe standard to every repository from config.env. Idempotent:
# safe to run repeatedly; it overwrites drift.
#
#   bin/apply.sh --dry-run        # show what it would do, change nothing
#   bin/apply.sh                  # all repositories from config.env
#   bin/apply.sh project-a        # only the given repositories
#
# Requires: bash (Git Bash is enough) and gh logged in as the repository owner.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config.env
source "$ROOT/config.env"

# Local contract: config.env defines OWNER, REPOS, EXCLUDE and ACTION_PATTERNS.
if ! declare -p REPOS >/dev/null 2>&1; then REPOS=(); fi
if ! declare -p EXCLUDE >/dev/null 2>&1; then EXCLUDE=(); fi
if ! declare -p ACTION_PATTERNS >/dev/null 2>&1; then ACTION_PATTERNS=(); fi

DRY=0; TARGETS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) TARGETS+=("$a") ;;
  esac
done
[[ "${OWNER:-}" != CHANGE_ME ]] || { echo "set OWNER in config.env" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "log in first: gh auth login" >&2; exit 1; }

FAILS=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; FAILS=$((FAILS+1)); }
note(){ printf '    %s\n' "$*"; }

# api METHOD PATH [JSON] - in --dry-run it only prints the change.
api() {
  local method=$1 path=$2 body=${3:-}
  if [[ $DRY == 1 && $method != GET ]]; then note "[dry-run] $method $path"; return 0; fi
  if [[ -n "$body" ]]; then
    printf '%s' "$body" | gh api -X "$method" "$path" --input - >/dev/null
  else
    gh api -X "$method" "$path" >/dev/null
  fi
}

# step "description" command... - one failing step does not abort the rest.
step() {
  local desc=$1 out; shift
  if out=$("$@" 2>&1); then ok "$desc"; [[ -n "$out" ]] && printf '%s\n' "$out"
  else bad "$desc"; note "$(printf '%s' "$out" | tail -n 2)"; fi
  return 0
}

if ((${#TARGETS[@]} == 0)); then
  if ((${#REPOS[@]})); then TARGETS=("${REPOS[@]}")
  else mapfile -t TARGETS < <(gh repo list "$OWNER" --visibility public --no-archived \
         --source --limit 300 --json name --jq '.[].name'); fi
fi

# --- steps -------------------------------------------------------------------

repo_settings() {  # squash-only merge, PR title/body, no wiki or Discussions, secret scanning
  api PATCH "repos/$1" '{
    "allow_squash_merge": true, "allow_merge_commit": false, "allow_rebase_merge": false,
    "squash_merge_commit_title": "PR_TITLE", "squash_merge_commit_message": "PR_BODY",
    "allow_auto_merge": true, "delete_branch_on_merge": true, "allow_update_branch": true,
    "has_wiki": false, "has_discussions": false,
    "security_and_analysis": {
      "secret_scanning": {"status": "enabled"},
      "secret_scanning_push_protection": {"status": "enabled"}}}'
}

security_features() {  # Dependabot, private reporting, immutable releases
  api PUT "repos/$1/vulnerability-alerts"
  api PUT "repos/$1/automated-security-fixes"
  api PUT "repos/$1/private-vulnerability-reporting"
  api PUT "repos/$1/immutable-releases"
}

codeql() {  # 422 = no supported language; then nothing is scanned, safe to ignore
  api PATCH "repos/$1/code-scanning/default-setup" '{"state":"configured","query_suite":"default"}'
}

actions_policy() {  # GitHub-owned actions plus ACTION_PATTERNS, SHA pinning, read-only token
  api PUT "repos/$1/actions/permissions" \
    '{"enabled":true,"allowed_actions":"selected","sha_pinning_required":true}'
  local p sep="" patterns="" body
  for p in "${ACTION_PATTERNS[@]}"; do
    patterns+="$sep\"$p\""
    sep=", "
  done
  body=$(printf '{"github_owned_allowed":true,"verified_allowed":false,"patterns_allowed":[%s]}' "$patterns")
  api PUT "repos/$1/actions/permissions/selected-actions" "$body"
  api PUT "repos/$1/actions/permissions/workflow" \
    '{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}'
  # Insurance in case pull requests from forks are ever enabled:
  api PUT "repos/$1/actions/permissions/fork-pr-contributor-approval" \
    '{"approval_policy":"all_external_contributors"}'
}

ruleset() {  # one ruleset for main; also removes rulesets left over from v1
  local repo=$1 id name
  id=$(gh api "repos/$repo/rulesets" --jq '.[] | select(.name=="baseline-main") | .id')
  if [[ -n "$id" ]]; then api PUT "repos/$repo/rulesets/$id" "$(cat "$ROOT/ruleset-main.json")"
  else api POST "repos/$repo/rulesets" "$(cat "$ROOT/ruleset-main.json")"; fi
  for name in baseline-tags baseline-branch-names; do
    id=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name==\"$name\") | .id")
    [[ -n "$id" ]] && api DELETE "repos/$repo/rulesets/$id"
  done
  return 0
}

labels() {  # exactly the labels from labels.tsv, everything else is removed
  local repo=$1 name color desc l keep want=()
  while IFS=$'\t' read -r name color desc; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    want+=("$name")
    if [[ $DRY == 1 ]]; then note "[dry-run] label $name"
    else gh label create "$name" -R "$repo" --color "$color" --description "$desc" --force >/dev/null; fi
  done <"$ROOT/labels.tsv"
  while IFS= read -r l; do
    [[ -z "$l" ]] && continue
    keep=0; for name in "${want[@]}"; do [[ "$l" == "$name" ]] && keep=1; done
    ((keep)) && continue
    if [[ $DRY == 1 ]]; then note "[dry-run] delete label '$l'"
    else gh label delete "$l" -R "$repo" --yes >/dev/null; fi
  done < <(gh label list -R "$repo" --limit 300 --json name --jq '.[].name')
}

# --- run ---------------------------------------------------------------------

for name in "${TARGETS[@]}"; do
  skip=0; for e in "${EXCLUDE[@]}"; do [[ "$name" == "$e" ]] && skip=1; done
  ((skip)) && continue
  R="$OWNER/$name"
  echo
  if [[ $DRY == 1 ]]; then echo "== $R (dry-run)"; else echo "== $R"; fi
  step "squash-only merge, auto-merge, branch cleanup, no wiki or Discussions, secret scanning" repo_settings "$R"
  step "Dependabot alerts and security updates, private vulnerability reporting, immutable releases" security_features "$R"
  step "CodeQL default setup (422 = repository without a supported language, safe to ignore)" codeql "$R"
  step "Actions: GitHub-owned actions plus the ACTION_PATTERNS allowlist, SHA-pinned, read-only token, fork PR approval" actions_policy "$R"
  step "main ruleset: pull request only, check 'ci-required', no force-push or deletion" ruleset "$R"
  label_list=$(grep -v '^#' "$ROOT/labels.tsv" | cut -f1 | paste -sd, -)
  step "labels: $label_list" labels "$R"
  note "MANUAL (no API): https://github.com/$R/settings -> Features -> Pull requests -> 'Collaborators only'"
done

echo
if ((FAILS)); then echo "Failed steps: $FAILS - see above."; exit 1; else echo "OK"; fi
