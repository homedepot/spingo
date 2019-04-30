#!/bin/bash

set -x
shopt -s extglob

## variables that will change for each target
## TODO: what can we do to automate the gathering of these variables?
JSON_FILE=""
GROUP=""
PROJECT=""

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

JSON_FILE_PATH="/spinnaker/accounts"

if [[ -z "$JSON_FILE" ]]; then
    echo -e "Current list of files waiting to be onboarded : \n"
    echo -e "----------------------------------------------- \n"
    gsutil ls gs://np-platforms-cd-thd-spinnaker-onboarding/ | sed 's/gs:\/\/np-platforms-cd-thd-spinnaker-onboarding\///' | sed 's/processed\///'
    echo "Please set the JSON_FILE variable inside the script"
    exit 0
fi

if [[ -z "$GROUP" ]] && [[ -z "$PROJECT" ]]; then
    echo "GROUP and PROJECG are both not set, cannot continue!"
    exit 0
fi

JSON_FULL_PATH="$JSON_FILE_PATH/$JSON_FILE"
echo "getting json file ($JSON_FILE) from bucket"

gsutil cp gs://np-platforms-cd-thd-spinnaker-onboarding/"$JSON_FILE" "$JSON_FULL_PATH"

BASENAME=$(basename -s '.json' "$JSON_FULL_PATH")

# The below will replace any number of characters inside the square brackets with a dash 
SANITIZED_NAME=${BASENAME//+([_])/-}
echo "Sanitized provider name: $SANITIZED_NAME"

echo "adding new appengine provider for $BASENAME"

hal config provider appengine account add "$SANITIZED_NAME" \
  --project "$PROJECT" \
  --json-path "$JSON_FULL_PATH" \
  --write-permissions="$GROUP" \
  --read-permissions="$GROUP"

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
  -d '{ "name": "'"$GROUP"'", "memberOf": ["'"$GROUP"'"] }' \
  "$FRONT50"/serviceAccounts

# force fiat to sync the change
curl -X POST "$FIAT"/roles/sync

kill "$PID"
