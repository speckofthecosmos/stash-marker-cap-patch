## Stash marker-cap patch build
##
## Clones stashapp/stash at develop (or configured ref), applies the
## marker-cap.patch, and builds a Docker image. Intended for users who
## want PR #6855's behavior (configurable marker preview duration cap)
## before the PR merges upstream.
##
## Usage:
##   make image          build for local arch
##   make run            build + run on port 9998 with an ephemeral test config
##   make clean          remove build artifacts
##   make refresh        re-clone source (throws away local patched tree)
##
## For multi-arch builds, use CI (push to main triggers a multi-arch build
## to ghcr.io). Local multi-arch push needs a registry target and auth,
## which this Makefile intentionally doesn't try to configure.
##
## Variables (override with `make VAR=value image`):
##   STASH_REF      upstream ref to build from (default: develop)
##   IMAGE          image name (default: stash-marker-cap)
##   TAG            image tag (default: develop)
##   PATCH          patch file (default: marker-cap.patch)

STASH_REPO ?= https://github.com/stashapp/stash.git
STASH_REF  ?= develop
PATCH      ?= marker-cap.patch
IMAGE      ?= stash-marker-cap
TAG        ?= develop
BUILD_DIR  ?= .build
SRC_DIR    := $(BUILD_DIR)/stash

.PHONY: all image run clean refresh patch-check

all: image

$(SRC_DIR):
	@mkdir -p $(BUILD_DIR)
	git clone --depth 1 --branch $(STASH_REF) $(STASH_REPO) $(SRC_DIR)

$(SRC_DIR)/.patched: $(SRC_DIR) $(PATCH)
	@echo ">>> Applying $(PATCH) to $(STASH_REF)"
	cd $(SRC_DIR) && git apply --check ../../$(PATCH) && git apply ../../$(PATCH)
	@touch $@

patch-check: $(SRC_DIR)
	@echo ">>> Dry-run: does $(PATCH) apply cleanly to $(STASH_REF)?"
	cd $(SRC_DIR) && git apply --check ../../$(PATCH) && echo "OK"

image: $(SRC_DIR)/.patched Dockerfile
	@echo ">>> Building $(IMAGE):$(TAG) from patched $(STASH_REF)"
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
