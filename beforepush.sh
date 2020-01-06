#!/usr/bin/env bash
docker run -v "$(pwd):/mnt" npmaile/spingo-sanity-tests bash -c /mnt/scripts/pre-push-tests.sh
