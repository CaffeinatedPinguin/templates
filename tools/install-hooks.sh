#!/usr/bin/env bash
# Register the repository-local pre-push hook (Git >= 2.54 config-based hooks).
# Only the local git config is modified: global hooks and .git/hooks stay untouched.
set -euo pipefail

if ! ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo "error: not inside a git repository" >&2
  exit 1
fi

COMMAND="bash \"$ROOT/tools/check.sh\" \"$ROOT\""

git config --local --replace-all hook.templates-check.event pre-push
git config --local --replace-all hook.templates-check.command "$COMMAND"

echo "Installed local git hook 'templates-check' for pre-push:"
echo "  $COMMAND"
echo "Bypass it in an emergency with: git push --no-verify"
