# Patched Stash build — honors marker end times by default.
# Derived from stashapp/stash's docker/build/x86_64/Dockerfile.
# The only deliberate deviation is NODE_OPTIONS=--max-old-space-size=8192
# in the frontend stage to avoid V8 heap OOM during terser/vite bundling.
#
# Build context should be a patched clone of stashapp/stash — see the
# sibling Makefile which handles clone + patch + build.

# Build Frontend
FROM node:24-alpine AS frontend
RUN apk add --no-cache make git
COPY ./ui/v2.5/package.json ./ui/v2.5/pnpm-lock.yaml /stash/ui/v2.5/
WORKDIR /stash
COPY Makefile /stash/
COPY ./graphql /stash/graphql/
COPY ./ui /stash/ui/
RUN npm install -g pnpm
RUN make pre-ui
RUN make generate-ui
ARG GITHASH
ARG STASH_VERSION
# Default V8 heap (~4GB) OOMs on Stash's bundle; bump before ui-only.
ENV NODE_OPTIONS=--max-old-space-size=8192
RUN BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S") make ui-only

# Build Backend
FROM golang:1.25-alpine AS backend
RUN apk add --no-cache make alpine-sdk
WORKDIR /stash
COPY ./go* ./*.go Makefile gqlgen.yml .gqlgenc.yml /stash/
COPY ./graphql /stash/graphql/
COPY ./scripts /stash/scripts/
COPY ./pkg /stash/pkg/
COPY ./cmd /stash/cmd/
COPY ./internal /stash/internal/
COPY ./ui /stash/ui/
RUN make generate-backend generate-login-locale
COPY --from=frontend /stash /stash/
ARG GITHASH
ARG STASH_VERSION
RUN make flags-release flags-pie stash

# Final Runnable Image
FROM alpine:latest
RUN apk add --no-cache ca-certificates vips-tools ffmpeg
COPY --from=backend /stash/stash /usr/bin/
ENV STASH_CONFIG_FILE=/root/.stash/config.yml
EXPOSE 9999
ENTRYPOINT ["stash"]
LABEL org.opencontainers.image.source="https://github.com/speckofthecosmos/stash-marker-cap-patch"
LABEL org.opencontainers.image.description="stashapp/stash develop + marker-cap PR #6855 patch"
