# Local checks

Run these checks before you push a workflow change.

The checks run in Docker, so you do not install any tools by hand. The workflows you check are
described in [workflows](workflows.md). Requirements:

- Docker, with the daemon running.
- Git 2.54 or newer for the config-based pre-push hook.

## Run the checks

```bash
bash tools/install-hooks.sh   # one-time: register the local pre-push hook
bash tools/check.sh           # actionlint + zizmor on .github
```

`tools/check.sh` runs both linters from digest-pinned images and reports every failure. The hook
runs the same script on `pre-push`. Skip the hook once with `git push --no-verify` in an
emergency.

## Pinned tool versions

Bump the version in `tools/check.sh` and in this table together:

| Tool | Version |
|---|---|
| [actionlint](https://github.com/rhysd/actionlint) | 1.7.12 |
| [zizmor](https://github.com/zizmorcore/zizmor) | 1.32.0 |

The images are pinned by digest, so the same tool version runs on every machine.
