#!/bin/bash

set -x
shopt -s extglob

## variables that will change for each target
## TODO: what can we do to automate the gathering of these variables?
KUBE_FILE=""
GROUP=""

KUBE_FILE_PATH="/spinnaker/accounts"

if [[ -z "$KUBE_FILE" ]]; then
    echo -e "Current list of files waiting to be onboarded : \n"
    echo -e "----------------------------------------------- \n"
    gsutil ls gs://np-platforms-cd-thd-spinnaker-onboarding/ | sed 's/gs:\/\/np-platforms-cd-thd-spinnaker-onboarding\///' | sed 's/processed\///'
    echo "Please set the KUBE_FILE variable inside the script"
    exit 0
fi

KUBE_CONFIG_FULL_PATH="$KUBE_FILE_PATH/$KUBE_FILE"
echo "getting kubeconfig file ($KUBE_FILE) from bucket"

gsutil cp gs://np-platforms-cd-thd-spinnaker-onboarding/"$KUBE_FILE" "$KUBE_CONFIG_FULL_PATH"

if [[ -z "$GROUP" ]]; then
    echo -e "Contact the requestor to ask them which of these groups should be setup for authorization for the cluster : \n"
    yq read "$KUBE_CONFIG_FULL_PATH" spinnaker-metadata.groups
    echo "Please set the GROUP variable inside the script"
    exit 0
fi

PROJECT=$(yq read "$KUBE_CONFIG_FULL_PATH" spinnaker-metadata.project 2>/dev/null)
REGION=$(yq read "$KUBE_CONFIG_FULL_PATH" spinnaker-metadata.location 2>/dev/null)
CONTEXT=$(yq read "$KUBE_CONFIG_FULL_PATH" contexts.0.name 2>/dev/null)
CLUSTER=$(yq read "$KUBE_CONFIG_FULL_PATH" clusters.0.name 2>/dev/null)
# The below will replace any number of characters inside the square brackets with a dash 
SANITIZED_NAME=${CLUSTER//+([_])/-}
echo "Sanitized provider name: $SANITIZED_NAME"


echo "adding new kubernetes provider for $CLUSTER"
hal config provider kubernetes account add "$SANITIZED_NAME" \
    --context "$CONTEXT" \
    --provider-version v2 \
    --docker-registries "docker-registry" \
    --write-permissions="$GROUP" \
    --read-permissions="$GROUP" \
    --only-spinnaker-managed=true \
    --kubeconfig-file="$KUBE_CONFIG_FULL_PATH"

echo "status code of adding account $?"

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
