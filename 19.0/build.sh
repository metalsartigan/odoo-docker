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

DOCKER_CONFIG=$(mktemp -d)
export DOCKER_CONFIG
trap 'rm -rf "$DOCKER_CONFIG"' EXIT

docker login -u token --password-stdin ghcr.io <<< "$GITHUB_TOKEN" > /dev/null

docker build --pull -t "${IMAGE}:${ODOO_VERSION}" .
docker push "${IMAGE}:${ODOO_VERSION}"
