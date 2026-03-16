#!/bin/sh
set -eu

IMAGE="${BUILD_IMAGE:-ghcr.io/sachnun/aqw-pocket:build}"

docker pull "$IMAGE"
