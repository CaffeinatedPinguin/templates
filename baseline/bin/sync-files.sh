#!/usr/bin/env bash
# Brings the standard files into a local clone of a repository through a PR (never push to main).
#   bin/sync-files.sh ../project-a              # missing files + PR
#   bin/sync-files.sh ../project-a --force      # also overwrite differing files
#   bin/sync-files.sh ../project-a --auto-merge # enable auto-merge after green CI
#   bin/sync-files.sh ../project-a --no-pr      # local commit on the branch only
# It also installs the local commit-msg hook (Conventional Commits).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CLONE=""; FORCE=0; AUTO=0; PR=1
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;; --auto-merge) AUTO=1 ;; --no-pr) PR=0 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) CLONE=$a ;;
  esac
done
[[ -d "$CLONE/.git" ]] || die "pass the path to a local clone of the repository"
require_tools
cd "$CLONE" || die "cannot enter $CLONE"
[[ -z "$(git status --porcelain)" ]] || die "uncommitted changes in $CLONE"

NWO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
NAME=${NWO#*/}
DEF=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
BR="chore/github-baseline"
git fetch -q origin "$DEF"
git switch -q -C "$BR" "origin/$DEF"
echo "== $NWO -> branch $BR"

SRC="$ROOT/repo-files"
while IFS= read -r rel; do
  case "$rel" in README.template.md) continue ;; esac
  if [[ ! -e "$rel" ]]; then
    mkdir -p "$(dirname "$rel")"; cp "$SRC/$rel" "$rel"; ok "added $rel"
  elif ! cmp -s "$SRC/$rel" "$rel"; then
    if ((FORCE)); then cp "$SRC/$rel" "$rel"; warn "overwrote $rel"
    else dim "differs from the template (leaving it): $rel"; fi
  fi
done < <(cd "$SRC" && find . -type f | sed 's#^\./##' | sort)
[[ -f scripts/ci.sh ]] && git add --chmod=+x scripts/ci.sh

# README: create only when missing; otherwise check the required sections.
if [[ ! -f README.md ]]; then
  sed -e "s/PROJECT_NAME/$NAME/g" -e "s/OWNER/$OWNER/g" "$SRC/README.template.md" > README.md
  ok "added README.md (fill in the content)"
else
  for h in Installation Usage Support Security License; do
    grep -qiE "^##[[:space:]]+$h" README.md || warn "README.md: missing section '## $h'"
  done
fi
[[ -n "$(ls LICENSE* 2>/dev/null)" ]] || warn "missing LICENSE - add one manually (e.g. MIT/Apache-2.0)"
for f in .github/SECURITY.md SECURITY.md; do
  [[ -f "$f" ]] && dim "$f is local - it overrides the global one from $OWNER/.github (remove it if unneeded)"
done

shopt -s nullglob
WF=(.github/workflows/*.yml .github/workflows/*.yaml)
if ((${#WF[@]})); then
  "$ROOT/bin/pin-actions.sh" "${WF[@]}"
  "$ROOT/bin/lint-workflows.sh" "${WF[@]}" || warn "workflow lint reported problems (above) - fix them before merge"
fi

# Local Conventional Commits hook
cp "$ROOT/hooks/commit-msg" .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg && ok "commit-msg hook"

git add -A
if git diff --cached --quiet; then ok "repository already matches - nothing to do"; git switch -q "$DEF"; exit 0; fi
git commit -q -m "chore: apply github baseline" \
  -m "Standard files from gh-baseline: PR labels and stale policy, pinned actions."
ok "commit on $BR"
((PR)) || exit 0
git push -q -u origin "$BR" --force-with-lease
url=$(gh pr create --head "$BR" --base "$DEF" --title "chore: apply github baseline" \
  --body $'## Why\n\nAlign the repository with the shared baseline (PR labels, stale policy, pinned actions).\n\n## How verified\n\n`ci-required` on this PR; `bin/audit.sh` after merge.' 2>/dev/null \
  || gh pr view "$BR" --json url --jq .url)
ok "PR: $url"
((AUTO)) && gh pr merge "$url" --auto --squash && ok "auto-merge enabled"
exit 0
