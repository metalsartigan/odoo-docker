#!/usr/bin/env bash
# Builds the base image from the master branch of metalsartigan/odoo-docker and pushes it to
# ghcr.io/metalsartigan/odoo:$ODOO_VERSION.
#
# Usage: base_image.sh
#
# Requires GITHUB_TOKEN set to a classic token with the repo and write:packages scopes.
set -euo pipefail

ODOO_VERSION=19.0
IMAGE=ghcr.io/metalsartigan/odoo
BUILDKIT_IMAGE=moby/buildkit:buildx-stable-1

cleanup() {
    # The builder's metadata lives in DOCKER_CONFIG, so it must be removed before that directory.
    if [[ -n "${BUILDER:-}" ]]; then
        docker buildx rm "$BUILDER" > /dev/null
    fi
    if [[ -n "${BUILDKIT_IMAGE_PULLED:-}" ]] && docker image inspect "$BUILDKIT_IMAGE" &> /dev/null; then
        docker image rm "$BUILDKIT_IMAGE" > /dev/null
    fi
    rm -rf "$DOCKER_CONFIG"
}

DOCKER_CONFIG=$(mktemp -d)
export DOCKER_CONFIG
trap cleanup EXIT

docker login -u token --password-stdin ghcr.io <<< "$GITHUB_TOKEN" > /dev/null

# A throwaway builder keeps the image, the pulled base image and the build cache off the host.
BUILDER=$(docker buildx create --driver docker-container --driver-opt image="$BUILDKIT_IMAGE")

# The builder pulls its image into the host's store on first use.
if ! docker image inspect "$BUILDKIT_IMAGE" &> /dev/null; then
    BUILDKIT_IMAGE_PULLED=1
fi

docker buildx build --builder "$BUILDER" --push -t "${IMAGE}:${ODOO_VERSION}" .
