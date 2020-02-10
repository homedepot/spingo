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
    command -v "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

bucket_check(){
    # This section here is because the gsutil tool has a VERY high error rate and needs to be retried
    TERRAFORM_REMOTE_GCS_NAME="$1"
    BUCKET_TITLE="$2"
    BUCKET_CHECK=$(gsutil ls gs://"$TERRAFORM_REMOTE_GCS_NAME" 2>&1)
    echo "Bucket Check : $BUCKET_CHECK"
    while [[ "$BUCKET_CHECK" =~ "Traceback" ]];do
        echo "Got an error checking for existance of gs://$TERRAFORM_REMOTE_GCS_NAME trying agian"
        sleep 2
        BUCKET_CHECK=$(gsutil ls gs://"$TERRAFORM_REMOTE_GCS_NAME" 2>&1)
        echo "Inner Bucket Check : $BUCKET_CHECK"
    done
    if [[ ! "$BUCKET_CHECK" =~ "BucketNotFoundException" ]]; then
        echo "Deleting the gs://$TERRAFORM_REMOTE_GCS_NAME bucket that holds the $BUCKET_TITLE"
        DELETED_BUCKET=1
        # This section here is because the gsutil tool has a VERY high error rate and needs to be retried
        while [[ "$DELETED_BUCKET" -ne 0 ]]; do
            echo "Attempting to delete the $BUCKET_TITLE bucket..."
            gsutil -m rm -r gs://"$TERRAFORM_REMOTE_GCS_NAME"
            DELETED_BUCKET="$?"
            sleep 2
        done
    else
        echo "$BUCKET_TITLE bucket gs://$TERRAFORM_REMOTE_GCS_NAME does not exist so nothing to delete"
    fi
}

destroy_tf(){
    DIR="$1"
    cd "$DIR" || { echo "failed to enter terraform directory $DIR"; return; }
    echo "Removing infrstructure from terraform directory $DIR"
    terraform state list >/dev/null 2>&1
    INIT_STATE_CHECK="$?"
    if [ "$INIT_STATE_CHECK" -eq 0 ]; then
        STATE_CHECK=$(terraform state list)
        if [ "$STATE_CHECK" == "" ]; then
            echo "No terraform state resources found so nothing to destroy"
            cd ..
            return
        fi
        limit=5
        n=1
        until [ $n -ge $limit ]
        do
            if ! terraform destroy -auto-approve && break
            then
                echo "Unable to destroy infrastructure successfully in $DIR so trying again (attempt $n of $limit)"
            fi
	    n=$((n+1))
            sleep 3
        done
        if [ $n -ge $limit ]; then
            echo "Unable to destroy infrastructure successfully in $DIR after $limit attempts so exiting"
            exit 1
        fi
        echo "sleep for 5 seconds to give the bucket lock time to close out"
        sleep 5
    else
        echo "No terraform state found so nothing to destroy"
    fi
    cd ..
}

while [ "$SCRIPT_CONFIRMATION" != "YES" ]; do
    echo "-----------------------------------------------------------------------------"
    echo "WARNING: Do not run this script unless you want to re-run initial_setup.sh"
    echo "This script is designed to remove all infrastructure and service accounts"
    echo "-----------------------------------------------------------------------------"
    echo -n "Enter YES to continue (ctrl-c to exit) : "
    read -r SCRIPT_CONFIRMATION
done

need "vault"
need "gcloud"
need "git"
need "gsutil"
need "jq"

CWD=$(pwd)
GIT_ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT_DIR" || { echo "unable to cd back to $GIT_ROOT_DIRECTORY, quitting"; exit 1; }

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

destroy_tf "halyard"
destroy_tf "monitoring-alerting"
destroy_tf "spinnaker"
destroy_tf "static_ips"
destroy_tf "dns"

if ! vault auth list >/dev/null 2>&1
then
  echo "not logged into vault!"
  echo "1. set VAULT_ADDR (e.g. 'export VAULT_ADDR=https://vault.example.com:10231')"
  echo "2. login: (e.g. 'vault login <some token>')"
  exit 1
fi

TERRAFORM_REMOTE_GCS_NAME="$PROJECT-tf"
HALYARD_GCS_NAME="$PROJECT-halyard-bucket"
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
    for role in $(gcloud projects get-iam-policy "$PROJECT" --flatten="bindings[].members" --format="json" --filter="bindings.members:$SA_EMAIL" | jq -r '.[].bindings.role')
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
rm -fdr ./monitoring-alerting/.terraform/
echo "deleting dynamic terraform variables"
rm ./dns/var*.auto.tfvars
rm ./halyard/var*.auto.tfvars
rm ./spinnaker/var*.auto.tfvars
rm ./monitoring-alerting/var*.auto.tfvars
echo "deleting dynamic terraform backend configs"
rm ./dns/override.tf
rm ./halyard/override.tf
rm ./spinnaker/override.tf
rm ./monitoring-alerting/override.tf

bucket_check "$TERRAFORM_REMOTE_GCS_NAME" "Terraform state"
bucket_check "$HALYARD_GCS_NAME" "Halyard"

echo "deletion complete"
cd "$CWD" || { echo "unable to return to $CWD" ; exit ; }
