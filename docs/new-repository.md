# Set up a new repository

Follow these steps when you create a new repository and want the standard settings and files.

The `baseline/` kit gives a repository the standard settings, labels, and files. The steps below
go from an empty repository to a first release. Steps 2 to 4 run from the `baseline/` directory;
the rest run in the new repository.

1. Create the repository, for example with `gh repo create name --public --clone --license mit`.
2. For one new repository, run `bin/apply.sh <name>` with the repository name. You do not edit
   `config.env` for this. The `REPOS` list in `config.env` is used only for runs without an
   argument.
3. Preview every change with `bin/apply.sh --dry-run` (add the name for one repository:
   `bin/apply.sh <name> --dry-run`) and show the owner the full output, especially the label names
   that will be deleted. Run `bin/apply.sh` only after the owner gives approval.
4. Apply the settings. The script is idempotent: run it again if a repository drifts later.
5. In every repository, set Settings -> Features -> Pull requests to **Collaborators only**.
6. Bring in the files from `baseline/repo-files/` through a pull request: `SECURITY.md`,
   `CONTRIBUTING.md`, the issue forms, the pull request template, and `dependabot.yml`. Copy them
   with `cp -rn <baseline>/repo-files/. .`.
7. Update `dependabot.yml` for the project. Only the `github-actions` ecosystem is active. Uncomment
   the ecosystems the project uses: `npm` for Node or pnpm, `docker` when there is a `Dockerfile`,
   and so on. For `docker` and `github-actions`, keep only `default-days` in `cooldown` (no
   `semver-*-days`). Every active ecosystem needs a `security` group with
   `applies-to: security-updates`, as the template shows.
8. Pin every action before you push. The copied workflow files use `@LATEST` placeholders, and a run
   that is not pinned to a full commit SHA ends in `startup_failure`. In the target repository run
   `<baseline>/bin/pin-actions.sh .github/workflows/*.yml`.
9. Make the CI script runnable. Record the executable bit with `git add --chmod=+x scripts/ci.sh`
   (Windows does not save it), then fill `scripts/ci.sh` with the project commands: lint, test, build.
10. Choose the CI for the project. A Node or pnpm project uses `examples/caller.yml`; any other
    project uses the generic `ci.yml` from `repo-files/.github/workflows/`.
11. Open the first pull request and wait until the required check `ci-required` is green. Right after
    `apply.sh`, the `dependency-review` job may fail because the "dependency graph" is still turned
    off. In that case rerun the failed jobs and confirm that `ci-required` becomes green.
12. Confirm that Dependabot is active and that its first grouped update opens on schedule.
13. Create the first release only after CI is green on `main` (see [releases](releases.md)).
