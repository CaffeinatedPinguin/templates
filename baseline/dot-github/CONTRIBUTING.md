# Contributing

This project is developed and maintained by a single person. To keep it sustainable:

- **Bugs and feature requests: open an issue** using one of the forms. Include everything the form asks for – reports that cannot be reproduced are labeled `needs-info` and closed after 14 days without a reply. Please search existing issues first.
- **Pull requests from outside contributors are not accepted** – only collaborators can open them. If you have a fix, describe it in the issue; the maintainer will implement it.
- **Security issues:** never public – see [SECURITY.md](SECURITY.md).

Thank you for using the project and taking the time to report problems.

---

## Conventions (maintainer and AI agents)

**Branches** – short-lived (≤ 2 days), cut from `main`:
`<type>/<issue>-<kebab-slug>` when there is an issue, otherwise `<type>/<kebab-slug>`,
e.g. `feat/42-csv-export`, `chore/bump-node`. Create it from the issue so GitHub links them:
`gh issue develop 42 --name feat/42-csv-export --checkout`.
Types: `feat fix docs refactor perf test build ci chore revert`.

**PR title = squash commit subject** – [Conventional Commits](https://www.conventionalcommits.org):
`type(scope)!: imperative summary` – lowercase, no trailing period, ≤ 72 chars recommended.
`!` marks a breaking change. `fix(security): …` marks a security fix.
No issue number in the subject – GitHub appends the PR number on squash: `feat(export): add csv format (#57)`.

**PR body = squash commit body** – *why*, then *how verified*, then the footer:
`Closes #N` (finishes the issue) or `Refs #N` (partial work). Every `feat`/`fix` should reference an issue;
CI warns when it does not. Commits on the branch need no footer – only the PR body reaches `main`.

**Merging** – squash only, after `ci-required` is green (auto-merge). `main` is always releasable.

**Releases** – tag `vMAJOR.MINOR.PATCH` (SemVer) via `gh release create vX.Y.Z --generate-notes`.
