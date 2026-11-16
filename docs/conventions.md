# Conventions

Read this when: you write a pull request title, commit message, branch name, or pull request body.

## Pull request title

The title must look like a Conventional Commit subject: `type(scope): description`, with an
optional `!` before the colon and no dot at the end. `scope` is optional. Allowed types:

- `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

A title starting with `Revert "` is also accepted. CI checks the title only; it does not check
commits, branch names, or the pull request text. Dependabot titles are exempt. The check lives in
the workflow described in [workflows](workflows.md).

Examples:

- `feat(api): add csv export`
- `fix: handle empty response`

## Commits and branches

These are recommendations, not checks:

- Write commits that explain why a change exists, one concern per commit.
- Keep branch names short and descriptive, for example `feat/csv-export`.

## Pull request body

A short body helps the reviewer:

- **Why**: the reason for the change.
- **How verified**: tests, a manual check, or a link to a green run.
- **Closes #N**: the issue this pull request closes.
