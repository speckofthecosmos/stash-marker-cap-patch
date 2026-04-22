# stash-marker-cap-patch

A Docker build recipe that ships [stashapp/stash](https://github.com/stashapp/stash)'s `develop` branch with [PR #6855](https://github.com/stashapp/stash/pull/6855) applied — making marker preview generation honor the marker's explicit end time instead of silently truncating at 20 seconds.

**This is a transitional artifact.** Once #6855 merges upstream, this repo becomes obsolete. Run `stashapp/stash:develop` directly at that point.

## What the patch does

Scene markers gained explicit end times in [PR #5311](https://github.com/stashapp/stash/pull/5311) (November 2024), but `pkg/scene/generate/marker_preview.go` was never updated to consume them — every marker preview has been hardcoded to 20 seconds, regardless of the `endSeconds` value in the UI and database. PR #6855 closes that loop: preview generation honors `endSeconds` by default, with an optional safety ceiling configurable via a new Settings field.

Full behavior details in the PR body: https://github.com/stashapp/stash/pull/6855

## Usage

Requires: Docker, `make`, `git`. Tested on macOS arm64 with OrbStack; should work anywhere Docker does.

```bash
git clone https://github.com/speckofthecosmos/stash-marker-cap-patch.git
cd stash-marker-cap-patch

# Build the image (~10–15 minutes first time)
make image

# Run a test instance on localhost:9998 with a scratch config
make run
```

For production use, point your existing `docker-compose.yml` at the resulting `stash-marker-cap:develop` image instead of `stashapp/stash:latest`. A sample compose file is included — copy and adapt the volume paths.

## Multi-arch build

The default `make image` builds for your local architecture. If you're building on Apple Silicon but deploying to an x86_64 NAS, use:

```bash
make image-multi
```

Requires Docker Buildx to be configured.

## Upgrading

When upstream `develop` moves forward, rebuild:

```bash
make refresh
make image
```

If the patch fails to apply cleanly (upstream refactored the affected files), open an issue — the patch needs regeneration from an updated PR branch.

## After the PR merges

Delete this repo's image, switch your compose file back to `stashapp/stash:develop` (or wait for the next stable release). No migration needed beyond that — your config and data are untouched by swapping images.

## To refresh existing marker previews

Existing preview files stay at their old 20-second durations until explicitly regenerated. To apply the new behavior to markers whose end times were previously truncated:

- In the Stash UI, run **Generate → Marker Previews** with **Overwrite Existing** enabled.
- Note that this regenerates ALL marker previews, not just the affected subset. For large libraries with few affected markers, this is imperfect.

To keep the old 20s ceiling, set **Max marker preview duration** to 20 under Settings → System → Preview Generation after updating.

## Variables

Override on the command line:

```bash
make image STASH_REF=main TAG=main           # build off main instead of develop
make image IMAGE=my-registry/stash-cap TAG=v1 # custom image name
```

Available variables: `STASH_REPO`, `STASH_REF`, `PATCH`, `IMAGE`, `TAG`, `BUILD_DIR`.

## Caveats

- **Default Node heap.** The upstream Dockerfile's frontend build hits V8 heap OOM on default settings. This repo's Dockerfile sets `NODE_OPTIONS=--max-old-space-size=8192` to work around it.
- **Not a permanent fork.** This repo is a thin patch-applier. Don't add features here — add them upstream.
- **Patch drift.** As upstream `develop` moves forward, the patch may stop applying cleanly. If that happens, the patch needs regeneration from the PR branch.

## License

The patch content derives from stashapp/stash which is licensed under AGPL. This repo's build tooling (Makefile, Dockerfile, docs) is released under the same terms for compatibility.
