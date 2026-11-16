# GitHub Actions templates

This repository holds the reusable GitHub Actions workflows that our projects share. Instead of copying CI code into every project, a project keeps a small caller workflow and calls these files by a pinned commit.
The companion `baseline/` kit (rulesets, labels and repository files for new repositories) is described in [baseline/README.md](baseline/README.md).

## Quick start

Copy [`examples/caller.yml`](examples/caller.yml) to `.github/workflows/ci.yml` in your project, replace every `<full-commit-sha>` with the commit you want, and push.

A caller points at one file by its full path and a full commit SHA:

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

## Which workflow do I need?

| Workflow | What it does | When to use it |
|---|---|---|
| `node-ci.yml` | Installs Node and pnpm, runs your scripts, uploads the build | Any Node/pnpm project |
| `docker.yml` | Builds the image, smoke-tests it, optionally publishes to GHCR | Projects with a `Dockerfile` |
| `release.yml` | Creates a GitHub release from generated notes | On version tags |
| `conventions.yml` | Checks the pull request title | Every pull request |
| `dependency-review.yml` | Fails on vulnerable dependencies in a pull request | Every pull request |

## `node-ci.yml`

Installs Node and pnpm, runs the requested `pnpm` scripts in order, and uploads the build artifact. A guard skips the expensive jobs when a release tag already points at this commit.

| Input | Default | What it does |
|---|---|---|
| `ref` | empty | Ref to check out, e.g. `refs/pull/<n>/head` to verify a pull request head. |
| `scripts` | `test lint typecheck build` | Space-separated `pnpm <script>` commands run in order. |
| `node-version-file` | `.nvmrc` | File read by `actions/setup-node`; pnpm comes from `packageManager`. |
| `runs-on` | `ubuntu-latest` | GitHub-hosted runner label (`ubuntu-*`, `windows-*`, `macos-*`); other labels are rejected. |
| `artifact-name` | `dist` | Uploaded artifact name; an empty value skips the upload. |
| `artifact-path` | `dist` | Path to upload; multi-line values are allowed. |
| `assets-name` | empty | Second artifact holding release files; empty uploads nothing extra. |
| `assets-path` | empty | Release asset files or globs uploaded to `assets-name`; multi-line values are allowed. |
| `check-release-tag` | `true` | On a tag, require it to equal `v` plus the `package.json` version. |

The workflow exposes one output: `skipped` is `'true'` when a stable release tag already points at the pushed commit, so the expensive jobs are not repeated.

To verify several operating systems, call the workflow once per matrix entry and give every variant a unique artifact name (or an empty one) so the uploads do not collide:

```yaml
jobs:
  verify:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
    uses: CaffeinatedPinguin/templates/.github/workflows/node-ci.yml@<full-commit-sha>
    with:
      runs-on: ${{ matrix.os }}
      artifact-name: dist-${{ matrix.os }}
```

## `docker.yml`

Builds an image with buildx, starts it and probes `/healthz`, then optionally publishes it to GHCR. Publishing is a separate job, so only that job gets write access.

| Input | Default | What it does |
|---|---|---|
| `image-name` | required | Lowercase image name; must match `^[a-z0-9][a-z0-9._-]{0,127}$`. |
| `context` | `.` | Build context. |
| `dockerfile` | `Dockerfile` | Dockerfile path. |
| `target` | empty | Optional build stage. |
| `artifact-name` | empty | Artifact to download into `artifact-path`; empty downloads nothing. |
| `artifact-path` | `dist` | Destination for the downloaded artifact. |
| `smoke-paths` | `/` | Space-separated paths probed through `/healthz`. |
| `push` | `false` | Publish `:<vX.Y.Z>` and `:stable` to GHCR; only a version tag may push. |
| `ref` | empty | Checkout ref for the build, e.g. `refs/pull/<n>/head` for a manual pull request run; the push job ignores it. |

## `release.yml`

Creates a GitHub release from generated notes and optional assets. Run it only for a `vX.Y.Z` tag.

| Input | Default | What it does |
|---|---|---|
| `title-prefix` | empty | Prefix for the release title. |
| `image-name` | empty | Image shown in the notes; empty omits the Docker section. |
| `assets-artifact` | empty | Artifact downloaded into the workspace; empty means no assets. |
| `assets-glob` | empty | Files passed to `gh release create`; after the download they sit in the workspace root. |

Use a separate artifact for assets (for example `assets-name` from `node-ci.yml`) so the build artifact layout is untouched.

## `conventions.yml`

Checks the pull request title. It takes no inputs and no secrets; the caller runs it on `pull_request` with `permissions: {}`.

- The title must look like a Conventional Commit subject (`type(scope): description`, optional `!`, no dot at the end) or start with `Revert "`.
- Pull requests from `dependabot[bot]` are exempt.
- An empty title (a run without a pull request) skips the check.
- Branch names and pull request text are not checked.

## `dependency-review.yml`

Runs `actions/dependency-review-action` on the pull request diff. The job needs `contents: read` only.

| Input | Default | What it does |
|---|---|---|
| `fail-on-severity` | `high` | Minimum vulnerability severity that fails the review. |

## How it stays safe

- Every action is pinned to a full commit SHA, so a moved tag cannot change the code underneath.
- Checkouts set `persist-credentials: false`, permissions are minimal per job, and `secrets: inherit` is never used.
- Reusable workflows never declare a `pull_request`, `pull_request_target` or `issue_comment` trigger. Callers may use `pull_request`, but pull request runs never receive secrets.
- A manual pull request check uses `workflow_dispatch` with `gh workflow run ci.yml -f pr=<n>` and checks out `refs/pull/<n>/head` without granting write access.
- `docker.yml` publishes only on a `vX.Y.Z` tag, so a branch or pull request run can never push an image.
- A run with a non-empty `ref` treats the code as untrusted: pnpm skips its cache and the Docker build reads but does not write the cache, so pull request code cannot poison what `main` and tags use.
- Only the owner pushes to `main` and `v*` tags; the branch ruleset blocks force pushes and deletions.

The required status check is a job named exactly `ci-required` in the caller. It waits for every job and fails when one failed or was cancelled:

```yaml
ci-required:
  if: always()
  needs: [verify, docker, release, conventions, dependency-review]
  runs-on: ubuntu-latest
  timeout-minutes: 1
  permissions: {}
  steps:
    - name: All jobs green
      env:
        RESULTS: ${{ join(needs.*.result, ' ') }}
      run: |
        for r in $RESULTS; do
          [[ "$r" == success || "$r" == skipped ]] || { echo "::error::job result: $r"; exit 1; }
        done
```

## Checking changes locally

Requires Docker and Git >= 2.54. Register the pre-push hook once, then use `tools/check.sh` any time:

```bash
bash tools/install-hooks.sh   # one-time: register the local pre-push hook
bash tools/check.sh           # actionlint + zizmor on .github
```

`tools/check.sh` runs both linters from digest-pinned images and reports every failure. Skip the hook in an emergency with `git push --no-verify`.

Pinned tool versions (bump them in `tools/check.sh` and here together):

| Tool | Version |
|---|---|
| [actionlint](https://github.com/rhysd/actionlint) | 1.7.12 |
| [zizmor](https://github.com/zizmorcore/zizmor) | 1.32.0 |
