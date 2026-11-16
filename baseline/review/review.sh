#!/usr/bin/env bash
# Reviews a pull request with your AI - on demand, no schedule, no secrets in the repository.
#   review/review.sh OWNER/REPO 42
#   AI_CMD='opencode run -m <provider/model>' review/review.sh OWNER/REPO 42
#   review/review.sh OWNER/REPO 42 | gh pr comment 42 -R OWNER/REPO -F -   # optional comment
#
# AI_CMD = any command that reads the prompt from stdin and writes the answer to stdout.
# The AI is called only when it makes sense: not for drafts, not for Dependabot,
# not when CI is red (fix what the machines found first).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=${1:?usage: review/review.sh OWNER/REPO NUMBER}
PR=${2:?usage: review/review.sh OWNER/REPO NUMBER}
AI_CMD=${AI_CMD:-"claude -p"}
MAX_LINES=${MAX_LINES:-1500}
LOCKFILES='(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|poetry\.lock|uv\.lock|Cargo\.lock|go\.sum)$'
PROMPT="$HERE/review-"
PROMPT+="prompt.md"

read -r DRAFT AUTHOR < <(gh pr view "$PR" -R "$REPO" --json isDraft,author --jq '"\(.isDraft) \(.author.login)"')
[[ "$DRAFT" == true ]]          && { echo "Draft - skipping." >&2; exit 0; }
[[ "$AUTHOR" == *dependabot* ]] && { echo "Dependabot - CI and dependency review are enough." >&2; exit 0; }
gh pr checks "$PR" -R "$REPO" --required >/dev/null 2>&1 \
  || { echo "CI is not green - fix it first." >&2; exit 0; }

DIFF=$(gh pr diff "$PR" -R "$REPO" | awk -v re="$LOCKFILES" '
  /^diff --git / { skip = ($3 ~ re); if (skip) print "[skipped lockfile " $3 "]" }
  !skip { print }')
LINES=$(wc -l <<<"$DIFF")
(( LINES <= MAX_LINES )) || { echo "The diff has $LINES lines - split the PR (limit $MAX_LINES)." >&2; exit 0; }

{
  cat "$PROMPT"
  echo; echo "<untrusted_pr>"
  gh pr view "$PR" -R "$REPO" --json title,body --jq '"TITLE: \(.title)\n\nBODY:\n\(.body)"'
  echo; echo "DIFF:"; printf '%s\n' "$DIFF"
  echo "</untrusted_pr>"
} | timeout 600 bash -c "$AI_CMD"
