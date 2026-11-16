#!/usr/bin/env bash
# Static, free security check of workflows (heuristics, no network).
#   bin/lint-workflows.sh .github/workflows/*.yml
# If zizmor is installed (pipx install zizmor), it is run as well.
set -uo pipefail
rc=0
report() { # report FILE DESCRIPTION "lines"
  local f=$1 msg=$2 hits=$3 l
  [[ -z "$hits" ]] && return 0
  rc=1
  while IFS= read -r l; do printf '  ✗ %s: %s -> %s\n' "$f" "$msg" "$l"; done <<<"$hits"
}

for f in "$@"; do
  [[ -f "$f" ]] || continue
  # 1. Triggers that run in a write-token / secret context on externally supplied data.
  report "$f" "forbidden trigger" "$(grep -nE '^\s*-?\s*(pull_request_target|workflow_run|issue_comment|pull_request_review_comment|discussion_comment)\s*(:|$)|^"?on"?:.*\b(pull_request_target|workflow_run|issue_comment|pull_request_review_comment|discussion_comment)\b' "$f")"
  # 2. Self-hosted runner in a public repository = foreign code on your machine.
  report "$f" "self-hosted runner" "$(grep -nE 'runs-on:.*self-hosted' "$f")"
  # 3. Missing global 'permissions:'.
  grep -qE '^permissions:' "$f" || report "$f" "missing top-level 'permissions:' (set 'permissions: {}')" "file"
  # 4. Actions not pinned to a full SHA.
  report "$f" "action without SHA pin" "$(grep -nE '^\s*-?\s*uses:\s*[^ #]+' "$f" | grep -vE 'uses:\s*\./|uses:\s*docker://|@[0-9a-f]{40}(\s|$)')"
  # 5. Script injection: user data interpolated directly (allowed only via env:/if:).
  report "$f" "possible injection - pass through env:" "$(grep -nE '\$\{\{\s*(github\.event\.(pull_request|issue|comment|review|head_commit|commits|discussion)|github\.head_ref)' "$f" \
      | grep -vE '^[0-9]+:\s*[A-Za-z_][A-Za-z0-9_-]*:\s*\$\{\{|^[0-9]+:\s*if:')"
  # 6. checkout without persist-credentials: false leaves the token in .git/config.
  if grep -qE 'uses:\s*actions/checkout@' "$f" && ! grep -qE 'persist-credentials:\s*false' "$f"; then
    report "$f" "actions/checkout without 'persist-credentials: false'" "file"
  fi
done

if command -v zizmor >/dev/null && (($#)); then
  zizmor --no-progress "$@" || rc=1
fi
exit $rc
