#!/bin/bash

set -x

## variables that will change for each target
## TODO: what can we do to automate the gathering of these variables?
PROJECT="hd-sqa-nonprod"
REGION="us-east1"
CLUSTER="spinnaker-us-east1"
KUBE_FILE="/spinnaker/accounts/gke_np-platforms-cd-thd_us-east1_spinnaker-us-east1.config"
CONTEXT="gke_np-platforms-cd-thd_us-east1_spinnaker-us-east1"
GROUP="TBD"

gsutil cp gs://np-platforms-cd-thd-spinnaker-onboarding/gke_np-platforms-cd-thd_us-east1_spinnaker-us-east1.config $KUBE_FILE

hal config provider kubernetes account add "${PROJECT}-${REGION}-${CLUSTER}" \
    --context "$CONTEXT" \
    --provider-version v2 \
    --docker-registries "docker-registry" \
    --write-permissions="$GROUP" \
    --read-permissions="$GROUP" \
    --only-spinnaker-managed=true \
    --kubeconfig-file="$KUBE_FILE"
