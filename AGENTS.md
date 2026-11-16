# AGENTS.md

## Project

This repository is `templates`, the shared GitHub Actions workflow library for the workspace.

## Domain

This project belongs to the `devops` domain. Follow `../ai/devops/AGENTS.md`.

## Local rules

- Reusable workflows and actions are public contracts. Keep inputs, outputs, permissions, and migration notes documented in `docs/workflows.md`.
- Pin every `uses:` to a full commit SHA with a `# vX.Y.Z` comment. Dependabot bumps these SHAs.
- Prefer small composite actions for shared logic and reusable workflows for shared jobs.
- Callers reference this repository by full commit SHA; Dependabot keeps the SHA up to date.
- Preserve compatibility unless a breaking change is deliberate and documented.
- Follow the security principles in `docs/security-principles.md`: minimal `permissions`, `persist-credentials: false` on every checkout, no PR triggers in reusable workflows; callers may use `pull_request` without secrets, no `secrets: inherit`, and `timeout-minutes` on every job.

## Verify

- Before every commit that changes `.github/`, run `bash tools/check.sh` (actionlint + zizmor in pinned Docker images).
- One-time setup: `bash tools/install-hooks.sh` registers a local `pre-push` hook that runs the same check.
- Local checks cannot exercise runner execution, GHCR pushes, or OIDC/token permissions; only CI verifies those.

## Required reading

- `../ai/devops/AGENTS.md`
- `README.md`
- `docs/`
- `baseline/README.md`
- The workflow or action being changed
