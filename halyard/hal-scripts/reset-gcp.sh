#!/bin/bash

gcloud auth activate-service-account --key-file="/home/${USER}/${USER}.json" --project "${PROJECT}"
gsutil cp gs://${BUCKET}/.kube/config /${USER}/.kube/config
