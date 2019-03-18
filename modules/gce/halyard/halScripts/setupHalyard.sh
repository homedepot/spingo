#!/bin/bash
set -x
GCS_SA_DEST="${ACCOUNT_PATH}"

# $SPIN_REDIS_ADDR is the redis address (ip:port format)


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


# set-up admin groups for fiat:
sudo tee /spinnaker/.hal/default/profiles/fiat-local.yml << FIAT_LOCAL
fiat:
  admin:
    roles:
      - gg_spinnaker_admins
FIAT_LOCAL

# set-up redis (memorystore):
sudo tee /spinnaker/.hal/default/profiles/gate-local.yml << GATE_LOCAL
redis:
  configuration:
    secure: true
GATE_LOCAL

sudo tee /spinnaker/.hal/default/service-settings/redis.yml << REDIS
overrideBaseUrl: redis://$SPIN_REDIS_ADDR
REDIS

echo "You may want to run 'hal deploy apply'"
