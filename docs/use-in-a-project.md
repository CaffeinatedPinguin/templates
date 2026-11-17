# Use the shared workflows in a project

Use this guide when a project calls the shared workflows.

Start from [`examples/caller.yml`](../examples/caller.yml). Copy it to
`.github/workflows/ci.yml` in your project and replace every `<full-commit-sha>` with one full
40-character commit SHA.

## Pin a full commit SHA

A tag can move; a full commit SHA cannot. Pin the full 40-character SHA so a moved tag cannot
swap the code under you. Dependabot reads the pin and opens a pull request when a newer release
exists, so you update the SHA by merging that pull request.

## The `ci-required` job

Branch protection waits for one job named exactly `ci-required`. It waits for the other jobs and
fails when one failed or was cancelled:

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

## Verify a pull request by hand

A caller can add a `workflow_dispatch` trigger with a `pr` input. A manual run checks out
`refs/pull/<n>/head` and runs the jobs without publishing:

```bash
gh workflow run ci.yml -f pr=<n>
```

Pull request runs never receive secrets, and every job keeps read-only permissions.
