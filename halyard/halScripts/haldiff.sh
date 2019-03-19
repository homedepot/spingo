#!/bin/bash
gsutil -m rsync -x ".*\.kube/http-cache/|.*\.kube/cache/" -d -r -n /${USER} gs://${BUCKET}

gsutil cp gs://${BUCKET}/.hal/config /tmp/halconfig && diff /tmp/halconfig /${USER}/.hal/config; rm /tmp/halconfig
