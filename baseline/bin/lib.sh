#!/usr/bin/env bash
# Shared helpers. Works in Git Bash (Windows), Linux and macOS.
# Requires only: bash 4+, gh (logged in), sed, grep, base64. No jq.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config.env
source "$ROOT/config.env"

DRY="${DRY:-0}"
FAILS=0
API_VER="2022-11-28"

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
ok()   { printf '  %s✓%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '  %s!%s %s\n' "$c_warn" "$c_off" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$c_err" "$c_off" "$*"; FAILS=$((FAILS+1)); }
dim()  { printf '  %s%s%s\n' "$c_dim" "$*" "$c_off"; }
die()  { printf '%sERROR:%s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }

require_tools() {
  command -v gh >/dev/null || die "gh not found (https://cli.github.com)"
  gh auth status >/dev/null 2>&1 || die "gh is not logged in: run gh auth login"
  [[ "$OWNER" != "CHANGE_ME" ]] || die "set OWNER in config.env"
}

# api METHOD PATH [gh api args...]
# In DRY=1 mode it performs no changes (GET still runs normally).
api() {
  local method=$1 path=$2; shift 2
  if [[ "$DRY" == 1 && "$method" != GET ]]; then
    dim "[dry-run] $method $path"
    [[ " $* " == *" --input - "* ]] && cat >/dev/null
    return 0
  fi
  gh api -X "$method" -H "X-GitHub-Api-Version: $API_VER" "$path" "$@"
}

# step "description" command... - runs a step without aborting the whole run on error.
step() {
  local desc=$1; shift
  local out
  if out=$("$@" 2>&1); then
    ok "$desc"
    if [[ "$DRY" == 1 && -n "$out" ]]; then printf '%s\n' "$out"; fi
  else
    bad "$desc"
    if [[ -n "$out" ]]; then dim "$(printf '%s' "$out" | tail -n 3)"; fi
  fi
  return 0
}

list_repos() {
  local all
  if ((${#REPOS[@]})); then all=$(printf '%s\n' "${REPOS[@]}")
  else
    all=$(gh repo list "$OWNER" --visibility public --no-archived --source \
            --limit 300 --json name --jq '.[].name')
  fi
  local r skip e
  while IFS= read -r r; do
    [[ -z "$r" ]] && continue
    skip=0
    for e in "${EXCLUDE[@]}"; do [[ "$r" == "$e" ]] && skip=1; done
    ((skip)) || printf '%s\n' "$r"
  done <<<"$all"
}

ruleset_id() { # ruleset_id OWNER/REPO NAME -> id or empty
  gh api "repos/$1/rulesets?includes_parents=false" \
    --jq ".[] | select(.name==\"$2\") | .id" 2>/dev/null || true
}
