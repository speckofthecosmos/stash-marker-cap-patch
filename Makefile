## Stash marker-cap patch build
##
## Clones stashapp/stash at develop (or configured ref) and merges the
## feature branch (PR #6855, configurable marker preview duration) onto it,
## then builds a Docker image. Intended for users who want PR #6855's
## behavior before it merges upstream.
##
## The feature is kept as a real branch on the fork and merged with git's
## 3-way merge rather than applied as a static patch, so unrelated upstream
## drift auto-resolves. A genuine same-line conflict aborts the merge — the
## signal to rebase the feature branch onto develop.
##
## Usage:
##   make image          build for local arch
##   make run            build + run on port 9998 with an ephemeral test config
##   make clean          remove build artifacts
##   make refresh        re-clone source (throws away local merged tree)
##   make merge-check    dry-run: does the feature branch merge cleanly?
##
## For multi-arch builds, use CI (push to main triggers a multi-arch build
## to ghcr.io). Local multi-arch push needs a registry target and auth,
## which this Makefile intentionally doesn't try to configure.
##
## Variables (override with `make VAR=value image`):
##   STASH_REF        upstream ref to build from (default: develop)
##   FEATURE_REPO     fork holding the feature branch
##   FEATURE_BRANCH   branch to merge in
##   IMAGE            image name (default: stash-marker-cap)
##   TAG              image tag (default: develop)

STASH_REPO     ?= https://github.com/stashapp/stash.git
STASH_REF      ?= develop
FEATURE_REPO   ?= https://github.com/speckofthecosmos/stash.git
FEATURE_BRANCH ?= feat/configurable-marker-preview-duration
IMAGE          ?= stash-marker-cap
TAG            ?= develop
BUILD_DIR      ?= .build
SRC_DIR        := $(BUILD_DIR)/stash

.PHONY: all image run clean refresh merge-check

all: image

$(SRC_DIR):
	@mkdir -p $(BUILD_DIR)
	@echo ">>> Cloning $(STASH_REF) (full history for 3-way merge)"
	git clone --filter=blob:none --branch $(STASH_REF) $(STASH_REPO) $(SRC_DIR)
	cd $(SRC_DIR) && \
	  git config user.email "marker-cap-build@localhost" && \
	  git config user.name "marker-cap-build" && \
	  git remote add feature $(FEATURE_REPO) && \
	  git fetch feature $(FEATURE_BRANCH)

$(SRC_DIR)/.merged: $(SRC_DIR)
	@echo ">>> Merging $(FEATURE_BRANCH) onto $(STASH_REF)"
	cd $(SRC_DIR) && git merge --no-edit feature/$(FEATURE_BRANCH)
	@touch $@

merge-check: $(SRC_DIR)
	@echo ">>> Dry-run: does $(FEATURE_BRANCH) merge cleanly onto $(STASH_REF)?"
	cd $(SRC_DIR) && \
	  git merge --no-commit --no-ff feature/$(FEATURE_BRANCH) >/dev/null 2>&1 && \
	  { echo "OK"; git merge --abort; } || \
	  { echo "CONFLICT — rebase the feature branch onto $(STASH_REF)"; git merge --abort; exit 1; }

image: $(SRC_DIR)/.merged Dockerfile
	@echo ">>> Building $(IMAGE):$(TAG) from merged $(STASH_REF)"
	cp Dockerfile $(SRC_DIR)/Dockerfile.markercap
	cd $(SRC_DIR) && \
	  docker build \
	    -f Dockerfile.markercap \
	    --build-arg GITHASH=$$(git rev-parse --short HEAD) \
	    --build-arg STASH_VERSION=$(STASH_REF)-marker-cap \
	    -t $(IMAGE):$(TAG) \
	    .

run: image
	@echo ">>> Starting test container on localhost:9998"
	@mkdir -p $(BUILD_DIR)/test-config
	docker run --rm -it \
	  -p 9998:9999 \
	  -v $(abspath $(BUILD_DIR)/test-config):/root/.stash \
	  --name $(IMAGE)-test \
	  $(IMAGE):$(TAG)

clean:
	rm -rf $(BUILD_DIR)

refresh:
	rm -rf $(SRC_DIR)
	$(MAKE) $(SRC_DIR)
