#!/bin/bash
gsutil -m rsync -x ".*\.kube/http-cache/|.*\.kube/cache/" -d -r gs://${BUCKET} /${USER} 
