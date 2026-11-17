# Releases

Read this before you cut a version tag, or when you want to know what a release produces.

## The tag

A release starts from a tag named `vX.Y.Z`, for example `v1.4.0`. The tag must match the version
in `package.json`: the tag is `v` plus that version. `node-ci.yml` checks this on every tag build
when `check-release-tag` is `true`; the inputs are listed in [workflows](workflows.md).

## What a tag runs

- `node-ci.yml` verifies the code and skips the expensive jobs when the tag already points at the
  pushed commit.
- `docker.yml` builds the image, smoke-tests it, and, because the run is a tag, publishes it to
  GHCR as `:<vX.Y.Z>` and `:stable`.
- `release.yml` creates the GitHub release from generated notes, with optional assets and a
  Docker section when `image-name` is set.

A branch or pull request run never publishes an image; only a `vX.Y.Z` tag can push.

## Immutable releases

A published release is immutable: its tag and assets cannot be changed afterwards. Create a new
tag for a new release instead of editing an old one.
