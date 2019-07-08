#!/bin/bash

# set -x
shopt -s extglob

# Change this to match the specific onboarding bucket name for your project
ONBOARDING_BUCKET_NAME="np-platforms-cd-thd-spinnaker-onboarding"

####################################################
########             Dependencies           ######## 
####################################################

# ensure that the required commands are present needed to run this script
die() { echo "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "gsutil"
need "hal"
need "curl"

ONBOARDING_BUCKET_BASE="gs://$ONBOARDING_BUCKET_NAME/"
ONBOARDING_BUCKET="${ONBOARDING_BUCKET_BASE}gke/"
ONBOARDING_BUCKET_COMPLETE="${ONBOARDING_BUCKET_BASE}processed/gke/"

KUBE_FILE_PATH="/spinnaker/accounts"
echo "-----------------------------------------------------------------------------"
echo " *****   GKE Cluster Onboarding Target   ***** "

projects=()
for proj in $(gsutil ls "$ONBOARDING_BUCKET" 2>/dev/null)
do
    if [[ $proj != "$ONBOARDING_BUCKET" ]]; then
        projects+=(${proj/$ONBOARDING_BUCKET/})
    fi
done

PS3="-----------------------------------------------------------------------------"$'\n'"Enter the number for the project to setup within Spinnaker : ";
select project in "${projects[@]}"
do
    if [ "$project" == "" ]; then
        echo "You must select a Project to onboard"
    else
        SELECTED_PROJECT_ONBOARDING_BUCKET="$ONBOARDING_BUCKET""$project"
        break;
    fi
done

targets=()
for value in $(gsutil ls "$SELECTED_PROJECT_ONBOARDING_BUCKET" 2>/dev/null)
do
    if [[ $value != "$SELECTED_PROJECT_ONBOARDING_BUCKET" ]]; then
        file=${value/$SELECTED_PROJECT_ONBOARDING_BUCKET/}
        if [[ "$file" != "sa.json" ]]; then
            targets+=(${file})
        fi
    fi
done
PS3="-----------------------------------------------------------------------------"$'\n'"Enter the number for the cluster to setup within Spinnaker : ";
select target in "${targets[@]}"
do
    if [ "$target" == "" ]; then
        echo "You must select a GKE Cluster to onboard"
    else
        cat ~/.hal/config | grep "$target" >/dev/null 2>&1
        if [ "$?" -eq 0 ]; then
            echo "-----------------------------------------------------------------------------"
            echo "The selected onboarding GKE Target appears to already be in the halyard config file : "
            echo "-----------------------------------------------------------------------------"
            cat ~/.hal/config | grep "$target" -C 5
            echo "-----------------------------------------------------------------------------"
            echo "You almost certainly don't want it added again so cowardly exiting onboarding"
            exit 1;
        else
            echo "-----------------------------------------------------------------------------"
            echo "GKE Cluster $target selected"
            KUBE_FILE="$target"
            break;
        fi
    fi
done

KUBE_CONFIG_FULL_PATH="$KUBE_FILE_PATH/$KUBE_FILE"
echo "getting kubeconfig file ($KUBE_FILE) from bucket"

# The purpose for this is to copy just the kube config file to the /spinnaker/accounts directory
gsutil cp "${SELECTED_PROJECT_ONBOARDING_BUCKET}${KUBE_FILE}" "$KUBE_CONFIG_FULL_PATH"

declare -A selected_groups=()
echo "-----------------------------------------------------------------------------"
echo " *****   Authorization Group(s) Selection   ***** "
echo "-----------------------------------------------------------------------------"
echo " Contact the requestor to ask them which of these groups should be setup for authorization for the cluster"
PS3="-----------------------------------------------------------------------------"$'\n'"Enter the number for the group to add to this account (Enter the number for Finished when done): "
select group in $(yq read "$KUBE_CONFIG_FULL_PATH" spinnaker-metadata.groups | sed 's/^- //') Finished Cancel
do
    if [ "$group" == "" ]; then
        echo "You must select a group"
    elif [ "$group" == "Finished" ]; then
        echo "all done"
        break;
    elif [ "$group" == "Cancel" ]; then
        echo "Cancelling at user reuqest"
        exit 1
    else
        if [[ -v selected_groups[$group] ]] ; then
            echo "group already selected"
        else
            selected_groups[$group]="$group"
            echo "adding group $group to selected groups"
        fi
    fi
done

selgroups=$(printf ", \"%s\"" "${selected_groups[@]}")
selgroups=${selgroups:2}
echo "Selected Groups : [ $selgroups ]"

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
    --only-spinnaker-managed=true \
    --kubeconfig-file="$KUBE_CONFIG_FULL_PATH"

echo "status code of adding account $?"

for selgroup in "${selected_groups[@]}"
do
    hal config provider kubernetes account edit "$SANITIZED_NAME" \
    --add-read-permission "$selgroup" \
    --add-write-permission "$selgroup"

    echo "status code of adding group $selgroup to account $?"
done

#close down connection to fiat & front50 if they already exists
fuser -k 7003/tcp >/dev/null 2>&1; fuser -k 8080/tcp  >/dev/null 2>&1
 
echo "patching fiat to add serice account for groups"
kubectl port-forward service/spin-front50 8080:8080 -n spinnaker >/dev/null 2>&1 &
while [ -z "$FRONT50_UP_PID" ]; do
  echo "waiting for connection to front50..."
  sleep 1
  FRONT50_UP_PID=$(fuser 8080/tcp)
done
echo "Connection to front50 obtained"

kubectl port-forward service/spin-fiat 7003:7003 -n spinnaker >/dev/null 2>&1 &
while [ -z "$FIAT_UP_PID" ]; do
  echo "waiting for connection to fiat..."
  sleep 1
  FIAT_UP_PID=$(fuser 7003/tcp)
done
echo "Connection to fiat obtained"

FRONT50="http://localhost:8080"
FIAT="http://localhost:7003"

# create the new _fiat_ service account for a given role
for selgroup in "${selected_groups[@]}"
do
    curl -X POST \
    -H "Content-type: application/json" \
    -d '{ "name": "'"$selgroup"'", "memberOf": ["'"$selgroup"'"] }' \
    "$FRONT50"/serviceAccounts
done
# force fiat to sync the change
curl -X POST "$FIAT"/roles/sync

fuser -k 8080/tcp >/dev/null 2>&1; fuser -k 7003/tcp >/dev/null 2>&1

gsutil mv "${SELECTED_PROJECT_ONBOARDING_BUCKET}" "${ONBOARDING_BUCKET_COMPLETE}"

echo "You should do a halldiff to make sure everything looks good then do an hda then a halpush"
echo "setup complete"
