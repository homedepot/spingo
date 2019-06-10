#!/bin/bash

# set -x
shopt -s extglob


## variables that will change for each target
# Change this to match the specific onboarding bucket name for your project
ONBOARDING_BUCKET_NAME="np-platforms-cd-thd-spinnaker-onboarding"
## TODO: what can we do to automate the gathering of these variables?
PROJECT=""
GROUP=""
declare -A selected_groups=()
selected_groups[$GROUP]="$GROUP"

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
ONBOARDING_BUCKET="${ONBOARDING_BUCKET_BASE}gae/"
ONBOARDING_BUCKET_COMPLETE="${ONBOARDING_BUCKET_BASE}processed/gae/"

JSON_FILE_PATH="/spinnaker/accounts"
echo "-----------------------------------------------------------------------------"
echo " *****   GAE Onboarding Target   ***** "

targets=()
for value in $(gsutil ls "$ONBOARDING_BUCKET" 2>/dev/null)
do
    if [[ $value != "$ONBOARDING_BUCKET" ]]; then
        targets+=(${value/$ONBOARDING_BUCKET/})
    fi
done
PS3="-----------------------------------------------------------------------------"$'\n'"Enter the number for the GAE target to setup within Spinnaker : ";
select target in "${targets[@]}"
do
    if [ "$target" == "" ]; then
        echo "You must select a GAE Target to onboard"
    else
        cat ~/.hal/config | grep "$target" >/dev/null 2>&1
        if [ "$?" -eq 0 ]; then
            echo "-----------------------------------------------------------------------------"
            echo "The selected onboarding GAE Target appears to already be in the halyard config file : "
            echo "-----------------------------------------------------------------------------"
            cat ~/.hal/config | grep "$target" -C 5
            echo "-----------------------------------------------------------------------------"
            echo "You almost certainly don't want it added again so cowardly exiting onboarding"
            exit 1;
        else
            echo "-----------------------------------------------------------------------------"
            echo "GAE Target $target selected"
            JSON_FILE="$target"
            break;
        fi
    fi
done

JSON_FULL_PATH="$JSON_FILE_PATH/$JSON_FILE"
echo "getting json file ($JSON_FILE) from bucket"

gsutil cp "${ONBOARDING_BUCKET}${JSON_FILE}" "$JSON_FULL_PATH"

BASENAME=$(basename -s '.json' "$JSON_FULL_PATH")

# The below will replace any number of characters inside the square brackets with a dash 
SANITIZED_NAME=${BASENAME//+([_])/-}
echo "Sanitized provider name: $SANITIZED_NAME"

if [[ -z "$GROUP" ]] || [[ -z "$PROJECT" ]]; then
    echo "Both GROUP and PROJECT must be set (see top of this script), cannot continue!"
    exit 1
fi

gsutil mv "${ONBOARDING_BUCKET}${JSON_FILE}" "${ONBOARDING_BUCKET_COMPLETE}${JSON_FILE}"

echo "adding new appengine provider for $BASENAME"

hal config provider appengine account add "$SANITIZED_NAME" \
  --project "$PROJECT" \
  --json-path "$JSON_FULL_PATH" \
  --write-permissions="$GROUP" \
  --read-permissions="$GROUP"

echo "status code of adding account $?"

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
