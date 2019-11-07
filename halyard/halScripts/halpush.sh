#!/bin/bash

gsutil -m rsync -x ".*\.kube/http-cache/|.*\.kube/cache/|.*\.kube/config|.*\.spin/config" -d -r /${USER} gs://${BUCKET}
