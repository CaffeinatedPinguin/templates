#!/usr/bin/env bash
# Local validation of the GitHub Actions in this repository.
# Runs actionlint and zizmor from pinned Docker images, exactly like CI.
# Usage: bash tools/check.sh [dir]   (dir defaults to the repository root)
set -uo pipefail

# Pinned tool images. Keep both in sync with the tool versions in README.md when bumping.
ACTIONLINT='rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667'
ZIZMOR='ghcr.io/zizmorcore/zizmor:1.32.0@sha256:3014cc8f68f663935f69b3c3e0e41f5ce102b268d97db13db0f62208747f860d'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=${1:-"$SCRIPT_DIR/.."}
if ! REPO=$(cd -- "$REPO" 2>/dev/null && pwd); then
  echo "error: directory not found: ${1:-$SCRIPT_DIR/..}" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is not installed or not on PATH; install Docker to run the checks" >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "error: cannot reach the Docker daemon; start Docker and try again" >&2
  exit 1
fi

if [ ! -d "$REPO/.github/workflows" ]; then
  echo "No .github/workflows in $REPO; nothing to check."
  exit 0
fi

# Git Bash needs a Windows path and no automatic path conversion in the mount.
export MSYS_NO_PATHCONV=1
MOUNT=$(cd -- "$REPO" && (pwd -W 2>/dev/null || pwd))

status=0

# Collect workflow files explicitly so an empty glob never reaches actionlint.
WORKFLOWS=()
shopt -s nullglob
for f in "$REPO"/.github/workflows/*.yml "$REPO"/.github/workflows/*.yaml; do
  WORKFLOWS+=(".github/workflows/${f##*/}")
done
shopt -u nullglob

echo "== actionlint"
if [ "${#WORKFLOWS[@]}" -eq 0 ]; then
  echo "No workflow files (*.yml, *.yaml) in $REPO/.github/workflows; skipping actionlint."
else
  ( cd -- "$REPO" && docker run --rm \
      -v "$MOUNT:/repo" -w /repo \
      "$ACTIONLINT" "${WORKFLOWS[@]}" ) || status=1
fi

echo "== zizmor"
( cd -- "$REPO" && docker run --rm \
    -v "$MOUNT:/repo" -w /repo \
    "$ZIZMOR" --offline --min-severity medium .github ) || status=1

if [ "$status" -ne 0 ]; then
  echo "checks failed" >&2
  exit 1
fi
echo "all checks passed"
