# Workflows

This page lists the shared workflows, their inputs and outputs. Read it before you change one.

This repository has six reusable workflows under `.github/workflows/`. A project calls one with
`uses:` and a full commit SHA; [use in a project](use-in-a-project.md) shows the caller. Each
section below lists the inputs with their defaults and the outputs. The file `check.yml` is not
reusable: it runs `tools/check.sh` on this repository.

## `node-ci.yml`

Installs Node and pnpm, runs the requested `pnpm` scripts in order, and uploads the build
artifact. A cheap guard skips the expensive jobs when a release tag already points at this
commit.

| Input | Default | What it does |
|---|---|---|
| `ref` | empty | Ref to check out, for example `refs/pull/<n>/head` to verify a pull request head. |
| `scripts` | `test lint typecheck build` | Space-separated `pnpm <script>` commands run in order. |
| `node-version-file` | `.nvmrc` | File read by `actions/setup-node`, resolved inside `working-directory`; pnpm comes from `packageManager`. |
| `working-directory` | `.` | Directory that holds `package.json` and the pnpm lockfile; `install`, the tag check and the scripts run there. |
| `runs-on` | `ubuntu-latest` | GitHub-hosted runner label (`ubuntu-*`, `windows-*`, `macos-*`); other labels are rejected. |
| `artifact-name` | `dist` | Uploaded artifact name; an empty value skips the upload. |
| `artifact-path` | `dist` | Path to upload; multi-line values are allowed. |
| `assets-name` | empty | Second artifact holding release files; empty uploads nothing extra. |
| `assets-path` | empty | Release asset files or globs uploaded to `assets-name`; multi-line values are allowed. |
| `check-release-tag` | `true` | On a tag, require it to equal `v` plus the `package.json` version. |

| Output | What it does |
|---|---|
| `skipped` | `'true'` when a stable release tag already points at the pushed commit, so the expensive jobs are not repeated. |

`artifact-path` and `assets-path` are resolved from the repository root, not from
`working-directory`, so a project whose app lives in a subdirectory passes the prefix itself (for
example `frontend/dist`).

To verify several operating systems, call the workflow once per matrix entry and give every
variant a unique artifact name (or an empty one) so the uploads do not collide:

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

## `maven-ci.yml`

Runs a Maven build through the project's Maven Wrapper. A cheap guard skips the expensive jobs
when a release tag already points at this commit. The `ubuntu-latest` runner has Docker, so tests
that use Testcontainers work without extra setup. This workflow builds the Maven project only; a
project that also has a Node/pnpm app calls `node-ci.yml` in a separate job, pointed at the app
directory through `working-directory`.

| Input | Default | What it does |
|---|---|---|
| `ref` | empty | Ref to check out, for example `refs/pull/<n>/head` to verify a pull request head. |
| `java-version` | `25` | Java version installed by `actions/setup-java`. |
| `java-distribution` | `temurin` | Java distribution installed by `actions/setup-java`. |
| `maven-args` | `-B -ntp verify` | Arguments passed to `./mvnw`; they are split on whitespace. |
| `artifact-name` | empty | Uploaded artifact name; an empty value skips the upload. |
| `artifact-path` | empty | Path to upload; multi-line values are allowed. |
| `check-release-tag` | `true` | On a tag, require it to equal `v` plus the Maven project version. |
| `timeout-minutes` | `25` | Timeout of the `verify` job. |

| Output | What it does |
|---|---|
| `skipped` | `'true'` when a stable release tag already points at the pushed commit, so the expensive jobs are not repeated. |

A project with the Maven Wrapper at the root and a pnpm app in `frontend/` calls both workflows
and lets `ci-required` wait for each job; the gate below is the branch-protection check described
in [use in a project](use-in-a-project.md#the-ci-required-job):

```yaml
jobs:
  verify:
    uses: CaffeinatedPinguin/templates/.github/workflows/maven-ci.yml@<full-commit-sha>
    with:
      java-version: "25"
      maven-args: -B -ntp verify

  frontend:
    uses: CaffeinatedPinguin/templates/.github/workflows/node-ci.yml@<full-commit-sha>
    with:
      working-directory: frontend
      artifact-path: frontend/dist

  ci-required:
    if: always()
    needs: [verify, frontend]
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

## `docker.yml`

Builds an image with buildx, starts it and probes `/healthz`, then optionally publishes it to
GHCR. Publishing is a separate job, so only that job gets write access.

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
| `ref` | empty | Checkout ref for the build, for example `refs/pull/<n>/head` for a manual pull request run; the push job ignores it. |

## `release.yml`

Creates a GitHub release from generated notes and optional assets. Run it only for a `vX.Y.Z`
tag.

| Input | Default | What it does |
|---|---|---|
| `title-prefix` | empty | Prefix for the release title. |
| `image-name` | empty | Image shown in the notes; empty omits the Docker section. |
| `assets-artifact` | empty | Artifact downloaded into the workspace; empty means no assets. |
| `assets-glob` | empty | Files passed to `gh release create`; after the download they sit in the workspace root. |

Use a separate artifact for assets (for example `assets-name` from `node-ci.yml`) so the build
artifact layout is untouched.

## `conventions.yml`

Checks the pull request title and takes no inputs and no secrets. The caller runs it on
`pull_request` with `permissions: {}`.

- The title must look like a Conventional Commit subject (`type(scope): description`, optional
  `!`, no dot at the end) or start with `Revert "`.
- Pull requests from `dependabot[bot]` are exempt.
- An empty title (a run without a pull request) skips the check.
- Branch names and pull request text are not checked.

## `dependency-review.yml`

Runs `actions/dependency-review-action` on the pull request diff. The job needs `contents: read`
only.

| Input | Default | What it does |
|---|---|---|
| `fail-on-severity` | `high` | Minimum vulnerability severity that fails the review. |
