<p align="center"><img src="docs/logo-purple.svg" width="96" alt="Smrodek logo"></p>

# GitHub Actions templates

Shared GitHub Actions workflows for this workspace. A project keeps one small caller workflow and
calls these files by a pinned commit, so CI code is not copied into every repository. The
`baseline/` kit holds the matching repository settings and files.

[![check workflow status](https://github.com/CaffeinatedPinguin/templates/actions/workflows/check.yml/badge.svg?branch=main)](https://github.com/CaffeinatedPinguin/templates/actions/workflows/check.yml)

**Status:** internal workflow library. There are no version tags; pin a full commit SHA.

## Quick start

Copy [`examples/caller.yml`](examples/caller.yml) into your project as
`.github/workflows/ci.yml`, replace every `<full-commit-sha>` with one full 40-character commit SHA,
and push.

```yaml
jobs:
  verify:
    uses: CaffeinatedPinguin/templates/.github/workflows/node-ci.yml@<full-commit-sha>
    with:
      scripts: test lint typecheck build
```

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
| [troubleshooting](docs/troubleshooting.md) | a run fails and you need the next step |
| [security principles](docs/security-principles.md) | you want the short list of rules |

## What is in this repository

| Path | What it is |
|---|---|
| `.github/workflows/` | shared workflows: `node-ci.yml`, `maven-ci.yml`, `docker.yml`, `release.yml`, `conventions.yml`, `dependency-review.yml`, and `check.yml` |
| `examples/` | `caller.yml`, a complete caller example |
| `baseline/` | repository settings kit; see [baseline/README.md](baseline/README.md) |
| `docs/` | the guides listed above |
