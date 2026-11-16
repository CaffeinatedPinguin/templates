#!/usr/bin/env bash
# Cheap, ad-hoc review of a PR with your AI (no schedulers, no secrets in the repository).
#   review/review-pr.sh OWNER/REPO 42            # print the review
#   review/review-pr.sh OWNER/REPO 42 --post     # + an "AI review (advisory)" PR comment
#   review/review-pr.sh OWNER/REPO 42 --force    # skip filters (Dependabot, red CI, cache)
#
# Order "static checks first, AI second" - the AI is called only when it makes sense:
#   draft -> skip | Dependabot -> skip (CI + dependency-review are enough)
#   CI red/pending -> skip | this commit already reviewed -> skip
#   PR > MAX_LINES -> do not review, split the PR
#   risky files -> AI_STRONG, everything else -> AI_CHEAP | lockfiles cut from the diff
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ai.env
source "$HERE/ai.env"

# Defaults keep the script usable when ai.env leaves a value unset.
MAX_LINES=${MAX_LINES:-400}
RISKY_RE=${RISKY_RE:-'(^|/)(\.github/workflows/|Dockerfile|package\.json)$'}
SKIP_RE=${SKIP_RE:-'(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock)$'}
AI_TIMEOUT=${AI_TIMEOUT:-300}
STATE_DIR=${STATE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/gh-baseline-review}
AI_CHEAP=${AI_CHEAP:-}
AI_STRONG=${AI_STRONG:-}

REPO=${1:?OWNER/REPO}; NUM=${2:?PR number}; shift 2
POST=0; FORCE=0
for a in "$@"; do case "$a" in --post) POST=1 ;; --force) FORCE=1 ;; esac; done
say() { printf '[%s#%s] %s\n' "$REPO" "$NUM" "$*" >&2; }

IFS=$'\t' read -r SHA DRAFT AUTHOR SIZE TITLE < <(gh pr view "$NUM" -R "$REPO" \
  --json headRefOid,isDraft,author,additions,deletions,title \
  --jq '[.headRefOid, .isDraft, .author.login, (.additions+.deletions), .title] | @tsv')
mkdir -p "$STATE_DIR"
STATE="$STATE_DIR/${REPO//\//_}-$NUM"

if ((!FORCE)); then
  [[ "$DRAFT" == true ]] && { say "draft - skipping"; exit 0; }
  [[ "$AUTHOR" == dependabot* || "$AUTHOR" == app/dependabot ]] && { say "Dependabot - skipping (CI + dependency-review)"; exit 0; }
  [[ -f "$STATE" && "$(cat "$STATE")" == "$SHA" ]] && { say "commit ${SHA:0:7} already reviewed"; exit 0; }
  if ! gh pr checks "$NUM" -R "$REPO" --required >/dev/null 2>&1; then
    say "CI is not green - static checks first, AI later"; exit 0
  fi
fi
if (( SIZE > MAX_LINES )); then
  say "PR has $SIZE changed lines (> $MAX_LINES) - split it; AI not called"; exit 0
fi

FILES=$(gh pr diff "$NUM" -R "$REPO" --name-only)
if grep -qE "$RISKY_RE" <<<"$FILES"; then TIER=strong; CMD=$AI_STRONG; else TIER=cheap; CMD=$AI_CHEAP; fi
[[ -n "$CMD" ]] || { say "no AI command for level '$TIER' - fill in review/ai.env"; exit 1; }

# Diff without lockfiles/generated files
DIFF=$(gh pr diff "$NUM" -R "$REPO" | awk -v re="$SKIP_RE" '
  /^diff --git / { f=$3; sub(/^a\//,"",f); skip = (f ~ re); if (skip) print "[skipped generated file: " f "]" }
  !skip { print }')
BODY=$(gh pr view "$NUM" -R "$REPO" --json body --jq .body)

PROMPT=$(mktemp); OUT=$(mktemp); trap 'rm -f "$PROMPT" "$OUT"' EXIT
{
  cat "$HERE/review-prompt.md"
  printf '\n<untrusted_pr>\nTITLE: %s\n\nBODY:\n%s\n\nCHANGED FILES:\n%s\n\nDIFF:\n%s\n</untrusted_pr>\n' \
    "$TITLE" "$BODY" "$FILES" "$DIFF"
} >"$PROMPT"

say "review ($TIER, ~$(wc -c <"$PROMPT") B prompt)…"
if ! timeout "$AI_TIMEOUT" bash -c "$CMD" <"$PROMPT" >"$OUT"; then
  say "AI failed or timed out (${AI_TIMEOUT}s)"; exit 1
fi
grep -q '^VERDICT:' "$OUT" || say "warning: response does not follow the format - check manually"

cat "$OUT"
echo "$SHA" >"$STATE"
cp "$OUT" "$STATE_DIR/${REPO//\//_}-$NUM-${SHA:0:7}.md"

if ((POST)); then
  { printf '### 🤖 AI review (advisory, %s model, commit %s)\n\n' "$TIER" "${SHA:0:7}"
    printf '```text\n'; cat "$OUT"; printf '\n```\n'
    printf '\n<sub>Automated, non-blocking. Decisions are made by the maintainer.</sub>\n'
  } | gh pr comment "$NUM" -R "$REPO" --body-file -
  say "comment added"
fi
