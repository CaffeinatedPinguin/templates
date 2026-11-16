#!/usr/bin/env bash
# One entry point for CI and local runs: lint -> typecheck -> test -> build.
# CI runs it with a 12 minute limit. Locally: ./scripts/ci.sh
set -euo pipefail

# Examples - keep only what applies to the project:
# npm ci && npm run lint && npm run typecheck && npm test && npm run build
# python -m pip install -e '.[dev]' && ruff check . && mypy . && pytest -q --timeout=120
# go vet ./... && go test -timeout 5m ./... && go build ./...

echo "scripts/ci.sh: add the project commands" >&2
