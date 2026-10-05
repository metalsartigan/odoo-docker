#!/usr/bin/env bash
# Builds the image from the current directory and, with the push action, publishes it to
# ghcr.io/metalsartigan/odoo:$ODOO_VERSION.
#
# Usage: build.sh build|push
#
#   build  Builds without keeping the result, to check that the build succeeds.
#   push   Builds and pushes. Requires GITHUB_TOKEN set to a classic token with the repo and
#          write:packages scopes.
set -euo pipefail

ODOO_VERSION=19.0
IMAGE=ghcr.io/metalsartigan/odoo
BUILDKIT_IMAGE=moby/buildkit:buildx-stable-1

usage() {
    echo "Usage: $(basename "$0") build|push" >&2
    exit 2
}

[[ $# -eq 1 ]] || usage
ACTION=$1
case "$ACTION" in
    build) OUTPUT=(--output type=cacheonly) ;;
    push) OUTPUT=(--push) ;;
    *) usage ;;
esac

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

if [[ "$ACTION" == push ]]; then
    docker login -u token --password-stdin ghcr.io <<< "$GITHUB_TOKEN" > /dev/null
fi

# A throwaway builder keeps the image, the pulled base image and the build cache off the host.
BUILDER=$(docker buildx create --driver docker-container --driver-opt image="$BUILDKIT_IMAGE")

# The builder pulls its image into the host's store on first use.
if ! docker image inspect "$BUILDKIT_IMAGE" &> /dev/null; then
    BUILDKIT_IMAGE_PULLED=1
fi

docker buildx build --builder "$BUILDER" "${OUTPUT[@]}" -t "${IMAGE}:${ODOO_VERSION}" .
