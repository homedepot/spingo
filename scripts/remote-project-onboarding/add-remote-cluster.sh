#!/bin/bash

set -x

## variables that will change for each target
## TODO: what can we do to automate the gathering of these variables?
PROJECT="hd-sqa-nonprod"
REGION="us-central1-a"
CLUSTER="helloworld--non-legacy-auth"
KUBE_FILE="/spinnaker/accounts/gke_hd-sqa-nonprod_us-central1-a_helloworld--non-legacy-auth.config"
CONTEXT="gke_hd-sqa-nonprod_us-central1-a_helloworld--non-legacy-auth"

hal config provider kubernetes account add "${PROJECT}-${REGION}-${CLUSTER}" \
    --context "$CONTEXT" \
    --provider-version v2 \
    --docker-registries "docker-registry" \
    --write-permissions=gg_pim_sshblk11_np \
    --read-permissions=gg_pim_sshblk11_np \
    --only-spinnaker-managed=true \
    --kubeconfig-file="$KUBE_FILE"