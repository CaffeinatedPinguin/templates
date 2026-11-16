# GitHub Actions templates

This repository holds the shared GitHub Actions workflows that our projects reuse. Instead of
copying CI code into every project, a project keeps one small caller workflow and calls these
files by a pinned commit. The `baseline/` kit holds the matching repository settings and files.

## Quick start

Copy [`examples/caller.yml`](examples/caller.yml) into your project as
`.github/workflows/ci.yml`, replace every `<full-commit-sha>` with one full 40-character commit
SHA, and push.

```yaml
jobs:
  verify:
    uses: CaffeinatedPinguin/templates/.github/workflows/node-ci.yml@<full-commit-sha>
    with:
      scripts: test lint typecheck build
```

The whole setup is three steps:

1. Copy the example into your project.
2. Replace `<full-commit-sha>` with a full 40-character commit SHA.
3. Commit and push; the next pull request runs the shared jobs.

Pin the full SHA so a moved tag cannot swap the code under you. Dependabot keeps the SHA current.

## Documentation

| Document | Read it when |
|---|---|
| [workflows](docs/workflows.md) | you need the inputs and outputs of a shared workflow |
| [set up a new repository](docs/new-repository.md) | you start a brand-new repository |
| [use in a project](docs/use-in-a-project.md) | you call the shared workflows from a project |
| [dependencies](docs/dependencies.md) | you manage dependency updates or add an action |
| [releases](docs/releases.md) | you cut a version tag or publish an image |
| [conventions](docs/conventions.md) | you write a pull request title or body |
| [local checks](docs/local-checks.md) | you change a workflow and check it before pushing |
| [troubleshooting](docs/troubleshooting.md) | a run fails and you need the next step |
| [security principles](docs/security-principles.md) | you want the short list of rules |

## What is in this repository

| Path | What it is |
|---|---|
| `.github/workflows/` | shared workflows: `node-ci.yml`, `docker.yml`, `release.yml`, `conventions.yml`, `dependency-review.yml`, and `check.yml` |
| `examples/` | `caller.yml`, a complete caller example |
| `baseline/` | repository settings kit; see [baseline/README.md](baseline/README.md) |
| `tools/` | `check.sh` and `install-hooks.sh` for local checks |
| `docs/` | the guides listed above |
