# Dependencies

Read this when: you manage dependency updates or add a new action.

Dependabot handles every dependency update. There is no second updater to configure. The
repository settings that switch it on are described in [baseline/README.md](../baseline/README.md).

## Routine updates

- Version updates run monthly and are grouped: minor and patch upgrades arrive in one pull
  request.
- Security updates start as soon as a vulnerability is published; they are not batched.
- Dependabot pull requests that are not a major update merge themselves once `ci-required` is
  green. A major update stays open for a manual decision.

## A major update pull request

1. Read the release notes in the pull request.
2. Run the project locally if the notes mention a breaking change.
3. Merge it when CI is green and the change is safe; otherwise close it and keep the current
   version until you can migrate.

## Add a new action

Add the action to the workflows, then pin it to a full commit SHA with
`baseline/bin/pin-actions.sh`. The pin and its `# vX.Y.Z` comment keep a moved tag from swapping
the code under you.
