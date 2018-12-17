#!/bin/bash

GCS_SA=spinnaker
GCS_SA_DEST=~/.gcp/gcp.json

GCS_SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:$GCS_SA" \
    --format='value(email)')

gcloud iam service-accounts keys create $GCS_SA_DEST \
    --iam-account $GCS_SA_EMAIL

hal config version edit --version $(hal version latest -q)

hal config storage gcs edit \
    --project $(gcloud info --format='value(config.project)') \
    --json-path ~/.gcp/gcp.json

hal config provider docker-registry enable

hal config provider docker-registry account add spinnaker \
    --address gcr.io \
    --password-file ~/.gcp/gcp.json \
    --username _json_key

hal config provider kubernetes enable

hal config provider kubernetes account add spinnaker \
    --docker-registries my-gcr-account \
    --context $(kubectl config current-context)