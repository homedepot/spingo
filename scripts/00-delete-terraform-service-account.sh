#!/bin/bash

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

need "vault"
need "gcloud"
need "git"
need "gsutil"

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

if [ -z "$SA_EMAIL" ]; then
    echo -e "\n\nUnable to determine email address for terraform service account. Does it still exist?"
    echo -e "Here is the list of remaining service accounts for project $PROJECT : \n"
    gcloud iam service-accounts list
    exit 1;
fi

PROJECT=$(gcloud info --format='value(config.project)')

echo "removing roles from $SERVICE_ACCOUNT_NAME for email : $SA_EMAIL"
gcloud --no-user-output-enabled projects remove-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role roles/resourcemanager.projectIamAdmin
gcloud --no-user-output-enabled projects remove-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role roles/iam.serviceAccountAdmin
gcloud --no-user-output-enabled projects remove-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role roles/iam.serviceAccountKeyAdmin
gcloud --no-user-output-enabled projects remove-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role roles/compute.admin
gcloud --no-user-output-enabled projects remove-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role roles/container.admin
gcloud --no-user-output-enabled projects remove-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role roles/storage.admin
gcloud --no-user-output-enabled projects remove-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role roles/iam.serviceAccountUser
gcloud --no-user-output-enabled projects remove-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role roles/dns.admin
gcloud --no-user-output-enabled projects remove-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role roles/redis.admin
gcloud --no-user-output-enabled projects remove-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role roles/cloudsql.admin

echo "deleting $SERVICE_ACCOUNT_NAME service account"
gcloud -q iam service-accounts delete "$SERVICE_ACCOUNT_NAME@$PROJECT.iam.gserviceaccount.com"

echo "deleting secret/$PROJECT/$SERVICE_ACCOUNT_DEST from vault"
vault delete secret/"$PROJECT"/"$SERVICE_ACCOUNT_NAME"

echo "deleting the bucket that holds the Terraform state"
gsutil rm -r gs://"$TERRAFORM_REMOTE_GCS_NAME"

echo "deleting the local Terraform directories pointing to the old bucket"
rm -fdr ./certbot/.terraform/
rm -fdr ./dns/.terraform/
rm -fdr ./halyard/.terraform/
rm -fdr ./spinnaker/.terraform/
echo "deleting dynamic terraform variables"
rm ./certbot/var*.auto.tfvars
rm ./dns/var*.auto.tfvars
rm ./halyard/var*.auto.tfvars
rm ./spinnaker/var*.auto.tfvars
echo "deleting dynamic terraform backend configs"
rm ./certbot/override.tf
rm ./dns/override.tf
rm ./halyard/override.tf
rm ./spinnaker/override.tf
echo "deletion complete"
cd "$CWD"
