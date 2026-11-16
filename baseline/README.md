# gh-baseline

One standard for every public GitHub repository: security, conventions and hygiene applied by a
script, checked by a script. No servers, no schedulers, no paid services.

Requirements: `gh` (logged in as the owner, `gh auth login` with the `repo` and `workflow` scopes),
`bash` (Git Bash on Windows is enough), `git`. Optional: `zizmor` for deeper workflow analysis.

## Contents

| Path | Purpose |
|---|---|
| `config.env` | the single file to edit: OWNER, repository list, switches |
| `bin/apply.sh` | configures repositories through the API (idempotent, `--dry-run`) |
| `bin/audit.sh` | checks compliance, changes nothing, non-zero exit on drift |
| `bin/sync-files.sh` | brings the standard files into a clone through a PR (never push to main) |
| `bin/pin-actions.sh` | pins `uses:` to full SHAs (required by the Actions settings); resolves `LATEST` |
| `bin/lint-workflows.sh` | static workflow checks: forbidden triggers, injections, missing pins |
| `rulesets/*.json` | protection for `main`, `v*` tags and the branch-name pattern |
| `labels.tsv` | the only allowed labels |
| `dot-github/` | contents of `OWNER/.github`: default issue forms, PR template, SECURITY, CONTRIBUTING |
| `repo-files/` | per-repository files: `pr-labels.yml`, `stale.yml`, README template |
| `hooks/commit-msg` | local Conventional Commits guard |
| `review/` | ad-hoc, cheap AI review of PRs |

`repo-files/.github/workflows/stale.yml` keeps `actions/stale@LATEST` on purpose.
`bin/sync-files.sh` runs `bin/pin-actions.sh` on the target workflows, which resolves `LATEST` to the
newest release and pins it to a full commit SHA.

## First run (pilot, about 30 minutes)

```bash
# 0. Sign in and configure the kit
gh auth login
$EDITOR config.env                         # OWNER=..., optionally REPOS=(...)

# 1. Global community health files (once per account)
gh repo create .github --public --clone && cp -r dot-github/. .github/
cd .github && git add -A && git commit -m "docs: add default community health files" && git push && cd ..

# 2. Audit, preview and apply repository settings
bin/audit.sh
bin/apply.sh --dry-run                     # review the list of changes
bin/apply.sh                               # apply

# 3. Manual settings (no API)
#    Settings -> General -> Features -> Pull requests: "Collaborators only" (issues stay open)
#    Settings -> Releases -> Enable release immutability

# 4. Add the standard files through a PR, never by pushing to main
bin/sync-files.sh ../project-a --no-pr     # creates the branch and commit locally
# open the PR, wait for ci-required to be green, then merge (squash only)

# 5. Stage the main ruleset after the first PR is merged
#    set MAIN_RULESET=1 in config.env, then:
bin/apply.sh project-a
bin/audit.sh
```

## New repository

```bash
gh repo create name --public --clone --license mit
bin/apply.sh name && bin/sync-files.sh ./name --auto-merge && bin/audit.sh name
```

## When something must be bypassed

The ruleset has no bypass, not even for you - on purpose. In an emergency: Settings -> Rules ->
`baseline-main` -> Enforcement: Disabled, fix the problem, turn it back on (or run
`bin/apply.sh name`). `bin/audit.sh` reports it if you forget.
