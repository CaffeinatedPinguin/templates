# GitHub Actions templates

Reusable GitHub Actions workflows for the workspace projects. A project keeps a
small caller workflow and delegates the shared jobs to this repository, pinned
to a full commit SHA. Renovate keeps the SHA current.

## Usage

1. Copy `examples/caller.yml` to `.github/workflows/ci.yml` in your project.
2. Replace the placeholder with the full commit SHA of this repository.
3. Pass inputs; do not copy workflow internals into the project.

Call a reusable workflow as
`CaffeinatedPinguin/templates/.github/workflows/<file>@<full-commit-sha>`.

## `node-ci.yml`

Installs Node and pnpm, runs the requested scripts, and uploads the build
artifact.

| Input | Default | Description |
|---|---|---|
| `ref` | empty | Checkout ref, e.g. `refs/pull/<n>/head` to verify a PR head. |
| `scripts` | `test lint typecheck build` | Space-separated `pnpm <script>` commands run in order. |
| `node-version-file` | `.nvmrc` | File read by `actions/setup-node`; pnpm comes from `packageManager`. |
| `artifact-name` | `dist` | Name of the uploaded artifact. |
| `artifact-path` | `dist` | Path to upload; multi-line values are allowed. |
| `assets-name` | empty | Name of a second artifact carrying files for the GitHub release; empty uploads nothing extra. |
| `assets-path` | empty | Release asset files or globs uploaded to `assets-name`; multi-line values are allowed. |
| `check-release-tag` | `true` | On a tag, require it to equal `v` plus the `package.json` version. |

Output: `skipped` is `'true'` when a stable release tag already points at the
pushed commit, so the expensive jobs are not repeated.

## `docker.yml`

Builds an image with buildx, smoke-tests it, and optionally publishes it to
GHCR.

| Input | Default | Description |
|---|---|---|
| `image-name` | required | Lowercase image name; must match `^[a-z0-9][a-z0-9._-]{0,127}$`. |
| `context` | `.` | Build context. |
| `dockerfile` | `Dockerfile` | Dockerfile path. |
| `target` | empty | Optional build stage. |
| `artifact-name` | empty | Artifact to download into `artifact-path`; empty downloads nothing. |
| `artifact-path` | `dist` | Destination for the downloaded artifact. |
| `smoke-paths` | `/` | Space-separated paths probed through `/healthz`. |
| `push` | `false` | Publish `:<vX.Y.Z>` and `:stable` to GHCR (separate job, `packages: write`). |
| `ref` | empty | Checkout ref for the `build` job, e.g. `refs/pull/<n>/head` for a manual PR run; the `push` job ignores it. |

## `release.yml`

Creates a GitHub release from generated notes.

| Input | Default | Description |
|---|---|---|
| `title-prefix` | empty | Prefix for the release title. |
| `image-name` | empty | Image shown in the notes; empty omits the Docker section. |
| `assets-artifact` | empty | Artifact downloaded into the workspace; empty means no assets. Use a separate artifact (e.g. `node-ci.yml` `assets-name`) so the build artifact layout is untouched. |
| `assets-glob` | empty | Files passed to `gh release create`; after the download they sit in the workspace root. |

## Security model

- No workflow uses `pull_request`, `pull_request_target`, or `issue_comment`.
  Start a PR run manually through the `workflow_dispatch` trigger with
  `gh workflow run ci.yml -f pr=<n>`; it checks out `refs/pull/<n>/head` without
  granting write permissions to the PR.
- Only the owner pushes to `main` and `v*` tags. Recommended branch ruleset:
  block force pushes and deletions for `main` and `v*`.
- `docker.yml` publishes only for a `vX.Y.Z` tag; any other ref fails before
  the GHCR login, so PR runs can never push an image.
- A run with a non-empty `ref` (manual PR verification) treats the code as
  untrusted: `node-ci.yml` disables the pnpm cache
  (`cache: ${{ inputs.ref == '' }}`) and `docker.yml` reads but does not write
  the Docker cache (`cache-to` is empty), so untrusted code cannot poison the
  cache used by `main` and tag runs.
- Every action is pinned to a full commit SHA, checkouts set
  `persist-credentials: false`, permissions are minimal per job, and
  `secrets: inherit` is never used.

## Cache

- pnpm caches its store through `pnpm/action-setup` (`cache: true`), keyed by the
  lockfile; `pnpm install --frozen-lockfile` runs as a separate step. The cache
  is disabled when `ref` is set, so PR code never writes it.
- Docker builds use the GitHub Actions cache (`type=gha`, `mode=max`) scoped per
  repository and image. Runs with `ref` set read it but do not write it.

## Local validation

Requires Docker and Git >= 2.54, which introduced config-based hooks.

```bash
bash tools/install-hooks.sh   # one-time: register the local pre-push hook
bash tools/check.sh           # actionlint + zizmor on .github
```

`tools/check.sh` runs both linters from digest-pinned images and reports every
failure; `tools/install-hooks.sh` only writes the local config, so global hooks
keep working. Skip the hook in an emergency with `git push --no-verify`.

Pinned tool versions (bump them in `tools/check.sh` and here together):

| Tool | Version |
|---|---|
| [actionlint](https://github.com/rhysd/actionlint) | 1.7.12 |
| [zizmor](https://github.com/zizmorcore/zizmor) | 1.32.0 |
