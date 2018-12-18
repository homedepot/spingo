#!/bin/bash
# About Script:
# This is used to initialize the halyard instance the first time until the bucket is
# filled with the halyard configuration.
# It is a primer and shouldn't be used excepting on a brand new project.

set -x

# The account that is actually managing
GCS_SA="svc-spinnaker-gcs-account"
# The location of the secret file
GCS_SA_DEST="/home/spinnaker/.gcp/spinnaker-gcs-account.json"
# The location of the spinnaker secret file.  SEE Terraform script
GCS_SPIN_DEST="/home/spinnaker/.gcp/spinnaker.json"
# The halyard user id.
GCP_HALYARD="spinnaker"

#gcloud auth activate-service-account --key-file=/home/spinnaker/.gcp/spinnaker.json
#gcloud beta container clusters get-credentials spinnaker-us-east1 --region us-east1 --project np-platforms-cd-thd

hal config storage gcs edit \
    --project $(gcloud info --format='value(config.project)') \
    --json-path "$GCS_SA_DEST"
hal config storage edit --type gcs

hal config provider docker-registry enable

hal config provider docker-registry account add "docker-registry" \
    --address gcr.io \
    --password-file "$GCS_SA_DEST" \
    --username _json_key
    

hal config provider kubernetes enable

hal config provider kubernetes account add halyard-gcr \
    --docker-registries "docker-registry" \
    --provider-version v2 \
    --context $(kubectl config current-context)

hal config version edit --version $(hal version latest -q)

hal config deploy edit --type distributed --account-name "halyard-gcr"
#Keeping this commented out as it is easier to deal with.
#hal deploy apply