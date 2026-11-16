# gh-baseline (v2, simplified)

One standard for every public repository: safe settings, shared files, simple CI.
No servers, no schedulers. Requires `gh` (logged in) and `bash` (Git Bash on Windows is enough).

| Path | Purpose |
|---|---|
| `config.env` | your login and (optionally) the repository list |
| `bin/apply.sh` | configures every repository through the API; `--dry-run` only prints |
| `ruleset-main.json` | the `main` protection ruleset |
| `labels.tsv` | the only allowed labels |
| `dot-github/` | contents of the `OWNER/.github` repository: SECURITY, CONTRIBUTING, issue forms, PR template |
| `repo-files/` | files for every repository: `ci.yml`, `stale.yml`, `scripts/ci.sh`, README template |
| `bin/pin-actions.sh` | resolves `@LATEST` in workflows to a full SHA (required) |
| `review/review.sh` | on-demand AI review of a pull request |
| `AGENTS.md` | instructions for your AI agent |

## Action allowlist

`bin/apply.sh` allows GitHub-owned actions by default. `ACTION_PATTERNS` in `config.env` is the only
exception: it lists the third-party actions and shared workflows that may also run (for example
`pnpm/action-setup@*` or `OWNER/templates/.github/workflows/node-ci.yml@*`). Every pattern must be
pinned to a full SHA by `bin/pin-actions.sh`. An empty or missing array means an empty allowlist.

Node/pnpm projects use the thin caller in `examples/caller.yml` (reusable workflows plus a
`ci-required` aggregator job) instead of `repo-files/.github/workflows/ci.yml`.

Dependency updates are handled by Renovate (configured outside the repositories), so the kit does not
ship `dependabot.yml`; Dependabot still provides alerts and security updates.

## Deployment

1. `config.env`: set `OWNER`.
2. `OWNER/.github`: `gh repo create .github --public --clone`, copy `dot-github/` into it, commit, push.
3. `bin/apply.sh --dry-run`, review the output (especially the labels it would delete), then `bin/apply.sh`.
4. In every repository, manually: Settings -> Features -> Pull requests -> **Collaborators only**.
5. Copy `repo-files/` into every repository through a PR (steps in `AGENTS.md`), then fill in `scripts/ci.sh`.

New repository: `gh repo create name --public --clone --license mit`, then steps 3-5.
Something drifted? Run `bin/apply.sh` again.
