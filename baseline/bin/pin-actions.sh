#!/usr/bin/env bash
# Pins every "uses: owner/repo@ref" to a full commit SHA:
#   uses: actions/checkout@<40-char sha> # v5.0.0
# A ref of "LATEST" means the newest release of the action. Lines that are already
# pinned are skipped (Renovate updates them later, keeping the version comment).
#   bin/pin-actions.sh .github/workflows/*.yml
set -euo pipefail
command -v gh >/dev/null || { echo "gh not found" >&2; exit 1; }
declare -A CACHE

resolve() { # resolve owner/repo ref -> "sha tag"
  local repo=$1 ref=$2 tag sha
  if [[ "$ref" == LATEST ]]; then
    tag=$(gh api "repos/$repo/releases/latest" --jq .tag_name)
  else tag=$ref; fi
  sha=$(gh api "repos/$repo/commits/$tag" --jq .sha)
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "cannot resolve $repo@$tag" >&2; return 1; }
  printf '%s %s' "$sha" "$tag"
}

for f in "$@"; do
  [[ -f "$f" ]] || continue
  while IFS= read -r spec; do
    # spec = owner/repo[/path]@ref
    action=${spec%@*}; ref=${spec##*@}
    [[ "$ref" =~ ^[0-9a-f]{40}$ ]] && continue
    repo=$(cut -d/ -f1-2 <<<"$action")
    key="$repo@$ref"
    [[ -n "${CACHE[$key]:-}" ]] || CACHE[$key]=$(resolve "$repo" "$ref")
    read -r sha tag <<<"${CACHE[$key]}"
    esc_spec=$(printf '%s' "$spec" | sed 's/[.[\*^$/]/\\&/g')
    sed -i -E "s/(uses:[[:space:]]*)${esc_spec}([[:space:]]*#.*)?$/\1${action//\//\\/}@${sha} # ${tag}/" "$f"
    echo "  $f: $action@$ref -> ${sha:0:12}… ($tag)"
  done < <(grep -oE 'uses:[[:space:]]*[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[A-Za-z0-9_.-]+' "$f" | sed -E 's/uses:[[:space:]]*//' | sort -u)
done
