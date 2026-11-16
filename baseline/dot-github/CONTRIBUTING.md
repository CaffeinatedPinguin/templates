# Contributing

This project is developed and maintained by a single person. To keep it sustainable:

- **Bugs and feature requests: open an issue** using one of the forms. Include everything the form asks for – reports that cannot be reproduced are labeled `needs-info` and closed after 14 days without a reply. Please search existing issues first.
- **Pull requests from outside contributors are not accepted** – only collaborators can open them. If you have a fix, describe it in the issue; the maintainer will implement it.
- **Security issues:** never public – see [SECURITY.md](SECURITY.md).

Thank you for using the project and taking the time to report problems.

---

## Conventions (maintainer and AI agents)

**Branches** – short-lived, cut from `main`, deleted after merge:
`<type>/<issue>-<slug>` when there is an issue (`feat/42-csv-export`), otherwise `<type>/<slug>` (`chore/bump-node`).
Create from the issue so GitHub links them: `gh issue develop 42 --name feat/42-csv-export --checkout`.

**PR title = the commit on `main`** (squash merge) – [Conventional Commits](https://www.conventionalcommits.org), checked by CI:
`type(scope)!: imperative summary` – lowercase, no trailing period, ≤ 72 chars.
Types: `feat fix docs refactor perf test build ci chore revert`; `!` marks a breaking change.
No issue number in the title – GitHub appends the PR number: `feat(export): add csv format (#57)`.

**PR body = the commit body** – *Why*, *How verified*, then `Closes #N` (or `Refs #N` for partial work).
Commits on the branch can be anything – they are squashed away.

**Releases** – `gh release create vX.Y.Z --generate-notes` (SemVer, tag always with `v`).
