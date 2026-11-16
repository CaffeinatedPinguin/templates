#!/usr/bin/env bash
# Reviews all open PRs (no drafts) in all repositories from config.env.
# Run manually during the maintenance routine or from an agent hook - not on a schedule.
#   review/review-all.sh [--post]
source "$(dirname "${BASH_SOURCE[0]}")/../bin/lib.sh"
require_tools
mapfile -t TARGETS < <(list_repos)
for name in "${TARGETS[@]}"; do
  while IFS= read -r n; do
    [[ -n "$n" ]] && "$ROOT/review/review-pr.sh" "$OWNER/$name" "$n" "$@" || true
  done < <(gh pr list -R "$OWNER/$name" --state open --draft=false --json number --jq '.[].number')
done
