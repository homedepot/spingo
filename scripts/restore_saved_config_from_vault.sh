#!/bin/bash

# This script will restore from vault all of the neessary prerequisites for
# terraform to run. For example, use this when running on a new machine

CWD=$(pwd)
GIT_ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT_DIR" || { echo "failed to go to git root directory $GIT_ROOT_DIR. Exiting"; exit 1;}

####################################################
########             Dependencies           ######## 
####################################################

# ensure that the required commands are present needed to run this script
die() { echo "$*" 1>&2 ; exit 1; }

need() {
    command -v "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "vault"

if ! vault auth list >/dev/null 2>&1
then
  echo "not logged into vault!"
  echo "1. set VAULT_ADDR (e.g. 'export VAULT_ADDR=https://vault.example.com:10231')"
  echo "2. login: (e.g. 'vault login <some token>')"
  exit 1
fi

PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
SERVICE_ACCOUNT_NAME="terraform-account"

echo "Restoring terraform account for project $PROJECT"
vault read -field "$PROJECT" secret/"$PROJECT"/"$SERVICE_ACCOUNT_NAME" > "$SERVICE_ACCOUNT_NAME".json
cp "$SERVICE_ACCOUNT_NAME".json ./halyard
cp "$SERVICE_ACCOUNT_NAME".json ./spinnaker
cp "$SERVICE_ACCOUNT_NAME".json ./static_ips
cp "$SERVICE_ACCOUNT_NAME".json ./monitoring-alerting
cp "$SERVICE_ACCOUNT_NAME".json ./dns
rm "$SERVICE_ACCOUNT_NAME".json

DNS_PROJECT=$(vault -field=value read secret/"$PROJECT"/local-vars-dns-gcp_project | cut -d "\"" -f 2 -)

if [ "$PROJECT" != "$DNS_PROJECT" ]; then
    echo "Restoring terraform account for seperate DNS project $DNS_PROJECT"
    vault read -field="$DNS_PROJECT" secret/"$DNS_PROJECT"/"$SERVICE_ACCOUNT_NAME" > "dns/$SERVICE_ACCOUNT_NAME-dns.json"
fi

echo "Restoring Overrides for $PROJECT"
for secret in $(vault list -format=json secret/"$PROJECT" | jq -r '.[] | select(startswith("local-override"))'); do
    echo "Restoring override for $secret"
    SECRET=$(vault read "$secret")
    DIR=$(echo "$SECRET" | awk '/vardirectory/ {print $2}')
    vault read -field value secret/"$PROJECT"/"$secret" > "$DIR/override.tf"
done

echo "Restoring variables for $PROJECT"
for secret in $(vault list -format=json secret/"$PROJECT" | jq -r '.[] | select(startswith("local-vars"))'); do
    echo "Restoring variable for $secret"
    SECRET=$(vault read "$secret")
    DIR=$(echo "$SECRET" | awk '/vardirectory/ {print $2}')
    if [ -z "$DIR" ]; then
        die "Unable to get vardirectory field from secret $secret (vardirectory should hold the directory to place the variable into)"
    fi
    VARIABLE_NAME=$(echo "$SECRET" | awk '/varname / {print $2}')
    if [ -z "$VARIABLE_NAME" ]; then
        die "Unable to get varname field from secret $secret (varname should hold the variable name to create)"
    fi
    SECRET_TYPE=$(echo "$SECRET" | awk '/vartype / {print $2}')
    if [ -z "$SECRET_TYPE" ]; then
        die "Unable to get vartype field from secret $secret (vartype should hold the type of the variable)"
    fi
    case $SECRET_TYPE in
        json)
            JSON_FILE_SUFFIX=".json"
            ;;
        text)
            JSON_FILE_SUFFIX=""
            ;;
        *)
            JSON_FILE_SUFFIX=""
            ;;
    esac
    vault read -field value secret/"$PROJECT"/"$secret" > "$DIR/var-$VARIABLE_NAME.auto.tfvars$JSON_FILE_SUFFIX"
done

cd "$CWD" || { echo "failed to return to directory $CWD"; exit;}
