#!/bin/bash

# Do not run this script unless you have already run 'terraform destoy' in all
#  of the diretories first and you want to re-run initial_setup.sh
# This script is designed to remove the service accounts that terraform requires

# PREREQUISITES
# logged-in to gcloud: `gcloud auth login`
# logged into vault
# `export VAULT_ADDR=https://vault.example.com:10231`
# `vault login <some token>`

# if you need to delete the service account, read https://cloud.google.com/iam/docs/understanding-service-accounts#deleting_and_recreating_service_accounts

####################################################
########             Dependencies           ######## 
####################################################

# ensure that the required commands are present needed to run this script
die() { echo "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

while [ "$SCRIPT_CONFIRMATION" != "YES" ]; do
    echo "-----------------------------------------------------------------------------"
    echo "WARNING: Do not run this script unless you have already run 'terraform destoy' in all"
    echo " of the diretories first and you want to re-run initial_setup.sh"
    echo "This script is designed to remove the service accounts that terraform requires"
    echo "-----------------------------------------------------------------------------"
    echo -n "Enter YES to continue (ctrl-c to exit) : "
    read SCRIPT_CONFIRMATION
done

need "vault"
need "gcloud"
need "git"
need "gsutil"
need "jq"

CWD=$(pwd)
GIT_ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT_DIR"

echo "-----------------------------------------------------------------------------"
CURR_PROJ=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
echo "Current gcloud project is : $CURR_PROJ"
echo "-----------------------------------------------------------------------------"
PS3="Enter the number for the Google Cloud Project to remove the terraform-account on (ctrl-c to exit) : ";
select projs in $(gcloud config list --format 'value(core.project)' 2>/dev/null)
do
    if [ "$projs" == "" ]; then
        echo "You must select a Google Cloud Project"
    else
        echo "-----------------------------------------------------------------------------"
        echo "Google Cloud Project $projs selected"
        PROJECT="$projs"
        break;
    fi
done

vault auth list >/dev/null 2>&1
if [[ "$?" -ne 0 ]]; then
  echo "not logged into vault!"
  echo "1. set VAULT_ADDR (e.g. 'export VAULT_ADDR=https://vault.example.com:10231')"
  echo "2. login: (e.g. 'vault login <some token>')"
  exit 1
fi

TERRAFORM_REMOTE_GCS_NAME="$PROJECT-tf"
SERVICE_ACCOUNT_NAME="terraform-account"
SERVICE_ACCOUNT_DEST="terraform-account.json"

SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:${SERVICE_ACCOUNT_NAME}" \
    --format='value(email)')

PROJECT=$(gcloud info --format='value(config.project)')

if [ -z "$SA_EMAIL" ]; then
    echo "No terraform service account left to clean up"
else
    echo "removing roles from $SERVICE_ACCOUNT_NAME for email : $SA_EMAIL"
    for role in $(gcloud projects get-iam-policy np-platforms-cd-thd --flatten="bindings[].members" --format="json" --filter="bindings.members:terraform-account@np-platforms-cd-thd.iam.gserviceaccount.com" | jq -r '.[].bindings.role')
    do
        gcloud --no-user-output-enabled projects remove-iam-policy-binding "$PROJECT" \
            --member serviceAccount:"$SA_EMAIL" \
            --role "$role"
    done

    echo "deleting $SERVICE_ACCOUNT_NAME service account"
    gcloud -q iam service-accounts delete "$SERVICE_ACCOUNT_NAME@$PROJECT.iam.gserviceaccount.com"
fi

echo "deleting secret/$PROJECT/$SERVICE_ACCOUNT_DEST from vault"
vault delete secret/"$PROJECT"/"$SERVICE_ACCOUNT_NAME"

echo "deleting the local Terraform directories pointing to the old bucket"
rm -fdr ./dns/.terraform/
rm -fdr ./halyard/.terraform/
rm -fdr ./spinnaker/.terraform/
echo "deleting dynamic terraform variables"
rm ./dns/var*.auto.tfvars
rm ./halyard/var*.auto.tfvars
rm ./spinnaker/var*.auto.tfvars
echo "deleting dynamic terraform backend configs"
rm ./dns/override.tf
rm ./halyard/override.tf
rm ./spinnaker/override.tf

echo "deleting the bucket that holds the Terraform state"
DELETED_BUCKET=1
while [ "$DELETED_BUCKET" -ne 0 ]; do
    echo "Attempting to delete the terraform state bucket..."
    gsutil -m rm -r gs://"$TERRAFORM_REMOTE_GCS_NAME"
    DELETED_BUCKET="$?"
    sleep 2
done

echo "deletion complete"
cd "$CWD"
