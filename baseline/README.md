# gh-baseline

One standard for every public repository: safe settings, shared files and simple CI.
It needs no servers and no background jobs. You only need `gh` (logged in) and `bash`
(Git Bash on Windows is enough).

This kit is for repositories owned by one person, where only the owner and trusted
collaborators merge changes. Apply it once, then rerun it whenever a repository drifts.

## Quick start

1. In `config.env`, set `OWNER` and (optionally) the repository list.
2. Create `OWNER/.github`, copy `dot-github/` into it, then commit and push.
3. Preview the settings, then apply them:

   ```bash
   bin/apply.sh --dry-run   # prints every change, including labels it would delete
   bin/apply.sh             # applies the settings through the GitHub API
   ```

4. In every repository, turn on **Collaborators only** under Settings -> Features -> Pull requests.
5. Copy `repo-files/` into each repository through a pull request (steps in `AGENTS.md`),
   then fill in `scripts/ci.sh` with the project commands.

## What is in the kit

| Path | What it is |
|---|---|
| `config.env` | your login and the optional repository list |
| `bin/apply.sh` | configures every repository; `--dry-run` only prints |
| `ruleset-main.json` | protection for the `main` branch |
| `labels.tsv` | the only four labels that stay |
| `dot-github/` | contents of the shared `OWNER/.github` repository |
| `repo-files/` | files copied into every repository |
| `bin/pin-actions.sh` | replaces `@LATEST` in workflows with a full commit SHA |
| `AGENTS.md` | instructions for your AI agent |

## What each setting does

- **Squash-only merge.** A pull request becomes exactly one commit on `main`, and that commit
  uses the PR title and body, so history stays readable.
- **One `main` ruleset.** Changes arrive only through a pull request with a green `ci-required`
  check. Force pushes and branch deletion are blocked.
- **`ci-required`.** Every repository runs one required job with this exact name. The shared
  `repo-files/.github/workflows/ci.yml` provides it.
- **Action allowlist.** Workflows may use GitHub-owned actions. `ACTION_PATTERNS` in `config.env`
  is the only exception: it lists third-party actions and shared workflows that may also run, for
  example `pnpm/action-setup@*` or `OWNER/templates/.github/workflows/node-ci.yml@*`.
  Every entry is pinned to a full SHA so a moved tag cannot swap the code under you.
- **Four labels.** `bug`, `enhancement`, `needs-info` and `dependencies`. Every other label is
  removed. The dry run names each one before anything happens.

## Add a new repository

```bash
gh repo create name --public --clone --license mit
```

Then run the Quick start steps for that repository: settings with `bin/apply.sh`, the manual
**Collaborators only** switch, and `repo-files/` through a pull request.

## Node and pnpm projects

These projects do not copy `repo-files/.github/workflows/ci.yml`. They use the thin caller in
`examples/caller.yml` instead: it calls the shared reusable workflows and adds a `ci-required`
aggregator job, so the required check keeps its name.

## Dependabot

Dependency updates are handled by Dependabot. The kit ships `dependabot.yml` (monthly version
updates, grouped minor and patch) and `dependabot-auto-merge.yml`. Dependabot alerts and security
updates are enabled by `bin/apply.sh`.

Dependabot PRs except major updates merge themselves once `ci-required` is green. Major updates
stay open for a manual decision.

## When something goes wrong

`bin/apply.sh` is idempotent: run it again to fix drifted settings. Run `--dry-run` first and read
the output, especially the labels it would delete. Files already copied into a repository are not
overwritten by `cp -rn`; update them through a pull request.
