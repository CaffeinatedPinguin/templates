# Security principles

Read this when: you add or change a workflow and want the short list of rules.

The workflow contracts are in [workflows](workflows.md).

- Pin every action and reusable workflow to a full commit SHA with a `# vX.Y.Z` comment, so a
  moved tag cannot swap the code under you.
- Pull request runs never receive secrets. Keep secrets out of any workflow a pull request can
  start.
- Give every job the smallest `permissions` it needs; start from `permissions: {}` and add only
  what a job uses.
- Set `persist-credentials: false` on every checkout.
- Publish an image only from a `vX.Y.Z` tag; a branch or pull request run must never push.
- Keep `timeout-minutes` on every job and never use `secrets: inherit`.
- Report a vulnerability through `SECURITY.md`, not in a public issue.
