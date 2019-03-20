#!/bin/bash

set -x

## variables that will change for each target
## TODO: what can we do to automate the gathering of these variables?
KUBE_FILE="/spinnaker/accounts/gke_np-com_us-central1-a_spinnaker--jxt19as.config"

PROJECT="np-com"
REGION="us-central1-a"
CLUSTER="spinnaker--jxt19as"
CONTEXT="gke_np-com_us-central1-a_spinnaker--jxt19as"
GROUP="gg_cloud_gcp_np-com-admin"

echo "getting kubeconfig file ($KUBE_FILE) from bucket"
gsutil cp gs://np-platforms-cd-thd-spinnaker-onboarding/gke_np-platforms-cd-thd_us-east1_spinnaker-us-east1.config $KUBE_FILE

echo "adding new kubernetes provider for $PROJECT-$REGION-$CLUSTER"
hal config provider kubernetes account add "$PROJECT-$REGION-$CLUSTER" \
    --context "$CONTEXT" \
    --provider-version v2 \
    --docker-registries "docker-registry" \
    --write-permissions="$GROUP" \
    --read-permissions="$GROUP" \
    --only-spinnaker-managed=true \
    --kubeconfig-file="$KUBE_FILE"

echo "patching fiat to add serice account for $GROUP"
hal deploy connect --service-names front50 fiat &
PID="$!"
sleep 10

FRONT50="http://localhost:8080"
FIAT="http://localhost:7003"

# create the new _fiat_ service account for a given role
curl -X POST \
  -H "Content-type: application/json" \
  -d '{ "name": "fiat-'"$GROUP"'", "memberOf": ["'"$GROUP"'"] }' \
  "$FRONT50"/serviceAccounts

# force fiat to sync the change
curl -X POST "$FIAT"/roles/sync

kill "$PID"
