# Troubleshooting

Start here when a workflow run fails.

### `startup_failure` on a run

The run stopped before any job started. Usually an action or a reusable workflow is not on the
allowed list, or a `uses:` entry is not pinned correctly.

- Open the workflow file and check every `uses:` line.
- Use an allowed action. If the action is genuinely needed, add it to the allowed list in the
  baseline configuration and pin it to a full commit SHA.
- Rerun the workflow after the fix.

### `ci-required` is missing or red

The branch needs one job named exactly `ci-required`.

- Missing: confirm the caller has the `ci-required` job with `if: always()` and a `needs:` list.
- Red: open the failed job in the run, fix the cause, and push again.
- A cancelled dependency also turns `ci-required` red; rerun the cancelled job.

### A `uses:` line is rejected as an invalid SHA

The reference is not a full 40-character commit SHA, or the tag comment does not match.

- Replace the tag or branch with the full commit SHA.
- Keep the `# vX.Y.Z` comment in sync with the release.
- Use `baseline/bin/pin-actions.sh` to resolve the pin.

### The image smoke test fails

The container did not answer on the health endpoint before the timeout.

- Check that the image serves `/healthz` on port 8080 inside the container.
- Check the `smoke-paths` input; every path must answer.
- Read the container log in the failed job.

### A pull request title is rejected

The title does not follow the Conventional Commits format; the rule is in
[conventions](conventions.md).

- Use `type(scope): description` with no dot at the end, for example `feat(api): add export`.
- Keep the allowed type word at the start.
- Edit the pull request title, then the check reruns.

### A Dependabot pull request stays open

A major update is never auto-merged.

- Review the release notes.
- Merge it by hand when CI is green, or close it and keep the current version.
