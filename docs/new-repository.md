# Set up a new repository

Read this when: you create a new repository and want the standard settings and files.

The `baseline/` kit gives a repository the standard settings, labels, and files. The steps below
go from an empty repository to a first release. Steps 2 and 3 run from the `baseline/` directory;
the rest run in the new repository.

1. Create the repository, for example with `gh repo create name --public --clone --license mit`.
2. In `config.env`, set `OWNER` and the optional repository list. Preview every change, including
   the labels that would be deleted, with `bin/apply.sh --dry-run`, and read the output.
3. Apply the settings with `bin/apply.sh`. The script is idempotent: run it again if a repository
   drifts later.
4. In every repository, set Settings -> Features -> Pull requests to **Collaborators only**.
5. Bring in the files from `baseline/repo-files/` through a pull request: `SECURITY.md`,
   `CONTRIBUTING.md`, the issue forms, the pull request template, and `dependabot.yml`. Copy them
   with `cp -rn <baseline>/repo-files/. .`.
6. Pin every action before you push. The copied workflow files use `@LATEST` placeholders, and a run
   that is not pinned to a full commit SHA ends in `startup_failure`. In the target repository run
   `<baseline>/bin/pin-actions.sh .github/workflows/*.yml`.
7. Make the CI script runnable. Record the executable bit with `git add --chmod=+x scripts/ci.sh`
   (Windows does not save it), then fill `scripts/ci.sh` with the project commands: lint, test, build.
8. Choose the CI for the project. A Node or pnpm project uses `examples/caller.yml`; any other
   project uses the generic `ci.yml` from `repo-files/.github/workflows/`.
9. Open the first pull request and wait until the required check `ci-required` is green.
10. Confirm that Dependabot is active and that its first grouped update opens on schedule.
11. Create the first release only after CI is green on `main` (see [releases](releases.md)).
