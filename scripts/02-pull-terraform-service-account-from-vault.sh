#!/bin/bash

CWD=$(pwd)
GIT_ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT_DIR"

####################################################
########             Dependencies           ######## 
####################################################

# ensure that the required commands are present needed to run this script
die() { echo "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "vault"

# can also run "gcloud config list --format 'value(core.project)' 2>/dev/null" to get the project name dynamically
PROJECT="np-platforms-cd-thd"
DNS_PROJECT="np-platforms-cd-thd"
SERVICE_ACCOUNT_NAME="terraform-account"
DNS_SERVICE_ACCOUNT_NAME="terraform-account-dns"

vault read -field "$PROJECT" secret/"$PROJECT"/"$SERVICE_ACCOUNT_NAME" > "$SERVICE_ACCOUNT_NAME".json
vault read -field "$DNS_PROJECT" secret/"$DNS_PROJECT"/"$SERVICE_ACCOUNT_NAME" > "$DNS_SERVICE_ACCOUNT_NAME".json
cp "$SERVICE_ACCOUNT_NAME".json ./halyard
cp "$SERVICE_ACCOUNT_NAME".json ./certbot
cp "$DNS_SERVICE_ACCOUNT_NAME".json ./dns
cd "$CWD"
