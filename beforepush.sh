#!/usr/bin/env bash
if ! command -v docker; then
	echo "Dependency Docker not installed. Exiting"
	exit 1
fi

GIT_ROOT=$(git rev-parse --show-toplevel)
docker run \
    -v "$GIT_ROOT:/mnt:ro" \
    npmaile/spingo-sanity-tests bash \
    -c /mnt/scripts/pre-push-tests.sh
