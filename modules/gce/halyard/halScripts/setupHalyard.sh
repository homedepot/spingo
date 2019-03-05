#!/bin/bash
set -x
GCS_SA=${USER}
GCS_SA_DEST="${ACCOUNT_PATH}"

hal config storage gcs edit \
    --project $(gcloud info --format='value(config.project)') \
    --json-path "$GCS_SA_DEST"
hal config storage edit --type gcs

hal config provider docker-registry enable

hal config provider docker-registry account add "${DOCKER}" \
    --address gcr.io \
    --password-file "$GCS_SA_DEST" \
    --username _json_key
    

hal config provider kubernetes enable

hal config provider kubernetes account add ${ACCOUNT_NAME} \
    --docker-registries "${DOCKER}" \
    --provider-version v2 \
    --only-spinnaker-managed=true \
    --context $(kubectl config current-context)

hal config version edit --version $(hal version latest -q)

hal config deploy edit --type distributed --account-name "${ACCOUNT_NAME}"

hal config edit --timezone America/New_York

echo "You may want to run 'hal deploy apply'"
