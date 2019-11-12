#!/bin/bash

# This script will initialize all of the neessary prerequisites for terraform to run

## Uncomment the line below if things go weird so you can see where it went awry
# set -x

# PREREQUISITES
# logged-in to gcloud: `gcloud auth login`
# logged into vault
# `export VAULT_ADDR=https://vault.example.com:10231`
# `vault login <some token>`

# if you need to delete the service account, see 00-delete-terraform-account.sh

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
need "openssl"
need "git"
need "cut"

terraform_override() {
    # $1 = terraform bucket name
    # $2 = terraform backend prefix
    # $3 = git root directory
    # $4 = terraform sub-project directory
    # $5 = GCP project name

    echo -e "terraform {\n backend \"gcs\" {\n bucket = \"$1\" \ncredentials = \"terraform-account.json\" \nprefix = \"$2\" \n} \n}" | terraform fmt - > "$3/$4/override.tf"
    if [ "$?" -ne 0 ]; then
        die "Unable to write terraform backend override file for $4"
    fi
    vault write "secret/$5/local-override-$2" "value"=@"$3/$4/override.tf" >/dev/null 2>&1
}

terraform_variable() {
    # $1 = terraform variable name
    # $2 = terraform variable value
    # $3 = git root directory
    # $4 = terraform sub-project directory
    # $5 = GCP project name

    echo -e "$1 = \"$2\"" > "$3/$4/var-$1.auto.tfvars"
    vault write "secret/$5/local-vars-$4-$1" "value"=@"$3/$4/var-$1.auto.tfvars" >/dev/null 2>&1
}

CWD=$(pwd)
GIT_ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT_DIR"

echo "-----------------------------------------------------------------------------"
CURR_PROJ=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
echo " *****   Current gcloud project is : $CURR_PROJ"
echo "-----------------------------------------------------------------------------"
PS3="Enter the number for the Google Cloud Project to setup Spinnaker on (ctrl-c to exit) : ";
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

VAULT_RESPONSE=$(vault status -format json | jq -r '. | select(.initialized == true and .sealed == false) | .initialized')
if [[ "$VAULT_RESPONSE" != "true" ]]; then
  echo "not logged into vault!"
  echo "1. set VAULT_ADDR (e.g. 'export VAULT_ADDR=https://vault.example.com:10231')"
  echo "2. login: (e.g. 'vault login <some token>')"
  exit 1
fi

echo "Enabling required Google Cloud APIs. This could take several minutes."
echo "enabling compute.googleapis.com service"
gcloud services enable compute.googleapis.com
echo "enabling iam.googleapis.com service"
gcloud services enable iam.googleapis.com
echo "enabling sqladmin.googleapis.com service"
gcloud services enable sqladmin.googleapis.com
echo "enabling cloudresourcemanager.googleapis.com"
gcloud services enable cloudresourcemanager.googleapis.com
echo "enabling container.googleapis.com"
gcloud services enable container.googleapis.com
echo "enabling dns.googleapis.com"
gcloud services enable dns.googleapis.com
echo "enabling redis.googleapis.com"
gcloud services enable redis.googleapis.com
echo "enabling admin.googleapis.com - Needed for Google OAuth"
gcloud services enable admin.googleapis.com

DOMAIN="$(gcloud config list account --format 'value(core.account)' 2>/dev/null | cut -d'@' -f2)"
USER_EMAIL="$(gcloud config list --format 'value(core.account)')"
TERRAFORM_REMOTE_GCS_NAME="$PROJECT-tf"
SERVICE_ACCOUNT_NAME="terraform-account"
SERVICE_ACCOUNT_DEST="terraform-account.json"

echo "creating $SERVICE_ACCOUNT_NAME service account"
gcloud iam service-accounts create \
    "$SERVICE_ACCOUNT_NAME" \
    --display-name "$SERVICE_ACCOUNT_NAME"

while [ -z $SA_EMAIL ]; do
  echo "waiting for service account to be fully created..."
  sleep 1
  SA_EMAIL=$(gcloud iam service-accounts list \
      --filter="displayName:${SERVICE_ACCOUNT_NAME}" \
      --format='value(email)')
done

echo "adding roles to $SERVICE_ACCOUNT_NAME for $SA_EMAIL"

gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/resourcemanager.projectIamAdmin'
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/iam.serviceAccountAdmin'
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/iam.serviceAccountKeyAdmin'
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/compute.admin'
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/container.admin'
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/storage.admin'
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/iam.serviceAccountUser'
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/dns.admin'
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/redis.admin'
gcloud --no-user-output-enabled projects add-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/cloudsql.admin'
gcloud --no-user-output-enabled projects add-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/monitoring.admin'
gcloud --no-user-output-enabled projects add-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/iam.roleAdmin'
gcloud --no-user-output-enabled projects add-iam-policy-binding  "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/pubsub.admin'

echo "generating keys for $SERVICE_ACCOUNT_NAME"
gcloud iam service-accounts keys create "$SERVICE_ACCOUNT_DEST" \
    --iam-account "$SA_EMAIL"

vault secrets enable -path=secret/"$PROJECT" -default-lease-ttl=0 -max-lease-ttl=0 kv >/dev/null 2>&1

echo "writing $SERVICE_ACCOUNT_DEST to vault in secret/$PROJECT/$SERVICE_ACCOUNT_NAME"
vault write secret/"$PROJECT"/"$SERVICE_ACCOUNT_NAME" "$PROJECT"=@${SERVICE_ACCOUNT_DEST}

echo "create the bucket that will store the Terraform State"
BUCKET_CHECK=$(gsutil mb -p "$PROJECT" gs://"$TERRAFORM_REMOTE_GCS_NAME"/ 2>&1)
echo "Bucket Check : $BUCKET_CHECK"
while [[ "$BUCKET_CHECK" =~ "Traceback" ]];do
    echo "Got an error creating gs://$TERRAFORM_REMOTE_GCS_NAME trying agian"
    sleep 2
    BUCKET_CHECK=$(gsutil mb -p "$PROJECT" gs://"$TERRAFORM_REMOTE_GCS_NAME"/ 2>&1)
    echo "Inner Bucket Check : $BUCKET_CHECK"
done

BUCKET_CHECK=$(gsutil versioning set on gs://"$TERRAFORM_REMOTE_GCS_NAME"/ 2>&1)
echo "Bucket Check : $BUCKET_CHECK"
while [[ "$BUCKET_CHECK" =~ "Traceback" ]];do
    echo "Got an error versioning gs://$TERRAFORM_REMOTE_GCS_NAME trying agian"
    sleep 2
    BUCKET_CHECK=$(gsutil versioning set on gs://"$TERRAFORM_REMOTE_GCS_NAME"/ 2>&1)
    echo "Inner Bucket Check : $BUCKET_CHECK"
done

vault read -field "value" secret/"$PROJECT"/keystore-pass >/dev/null 2>&1

if [[ "$?" -ne 0 ]]; then
    echo "-----------------------------------------------------------------------------"
    echo " *****   There is no keystore password stored within vault. Please enter a password you want to use or leave blank to create a random one."
    echo "-----------------------------------------------------------------------------"
    read USER_KEY_PASS
    if [ "$USER_KEY_PASS" == "" ]; then
        echo "creating random keystore password and storing within vault"
        KEY_PASS=$(openssl rand -base64 29 | tr -d "=+/" | cut -c1-25)
    else
        echo "storing user defined keystore password within vault"
        KEY_PASS="$USER_KEY_PASS"
    fi
    vault write secret/"$PROJECT"/keystore-pass "value=$KEY_PASS"
fi
cp "$SERVICE_ACCOUNT_DEST" ./spinnaker
cp "$SERVICE_ACCOUNT_DEST" ./halyard
cp "$SERVICE_ACCOUNT_DEST" ./dns
cp "$SERVICE_ACCOUNT_DEST" ./static_ips
cp "$SERVICE_ACCOUNT_DEST" ./monitoring-alerting
rm "$SERVICE_ACCOUNT_DEST"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "np" "$GIT_ROOT_DIR" "spinnaker" "$PROJECT"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "np-hal-vm" "$GIT_ROOT_DIR" "halyard" "$PROJECT"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "np-dns" "$GIT_ROOT_DIR" "dns" "$PROJECT"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "np-static-ips" "$GIT_ROOT_DIR" "static_ips" "$PROJECT"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "spingo-monitoring" "$GIT_ROOT_DIR" "monitoring-alerting" "$PROJECT"

terraform_variable "gcp_project" "$PROJECT" "$GIT_ROOT_DIR" "spinnaker" "$PROJECT"
terraform_variable "gcp_project" "$PROJECT" "$GIT_ROOT_DIR" "halyard" "$PROJECT"
terraform_variable "gcp_project" "$PROJECT" "$GIT_ROOT_DIR" "static_ips" "$PROJECT"
terraform_variable "gcp_project" "$PROJECT" "$GIT_ROOT_DIR" "monitoring-alerting" "$PROJECT"

terraform_variable "certbot_email" "$USER_EMAIL" "$GIT_ROOT_DIR" "halyard" "$PROJECT"

# enter a wildcard domain to be used
echo "-----------------------------------------------------------------------------"
echo " *****   Managed Domain   *****"
echo "-----------------------------------------------------------------------------"
while [ -z $DOMAIN_TO_MANAGE ]; do
    echo -n "What is the domain to manage for Cloud DNS? (example *.spinnaker.example.com would be spinnaker.example.com)?  "
    read DOMAIN_TO_MANAGE
done

terraform_variable "cloud_dns_hostname" "$DOMAIN_TO_MANAGE" "$GIT_ROOT_DIR" "dns" "$PROJECT"
terraform_variable "cloud_dns_hostname" "$DOMAIN_TO_MANAGE" "$GIT_ROOT_DIR" "spinnaker" "$PROJECT"
terraform_variable "cloud_dns_hostname" "$DOMAIN_TO_MANAGE" "$GIT_ROOT_DIR" "halyard" "$PROJECT"

# choose a project that will manage the DNS
echo "-----------------------------------------------------------------------------"
echo " *****   Managed DNS Google Cloud Project    *****"
echo "-----------------------------------------------------------------------------"
PS3="Enter the number for the Google Cloud Project that will use Cloud DNS to manage the DNS zone (it can be the same project as $PROJECT) (ctrl-c to exit) : ";
select dns_project in $(gcloud projects list --format='value(projectId)' --sort-by='projectId' 2>/dev/null)
do
    if [ "$dns_project" == "" ]; then
        echo "You must select a Managed DNS GCP Project"
    else
        echo "-----------------------------------------------------------------------------"
        echo "Managed DNS Google Cloud Project $dns_project selected"
        terraform_variable "managed_dns_gcp_project" "$dns_project" "$GIT_ROOT_DIR" "spinnaker" "$PROJECT"
        terraform_variable "gcp_project" "$dns_project" "$GIT_ROOT_DIR" "dns" "$PROJECT"
        vault write "secret/$PROJECT/dns_project_name" "value=$dns_project" >/dev/null 2>&1
        break;
    fi
done

# choose a region to place the cluster into
echo "-----------------------------------------------------------------------------"
echo " *****   Google Cloud Project Region    *****"
echo "-----------------------------------------------------------------------------"
PS3="Enter the number for the Google Cloud Project Region to setup the Spinnaker cluster on (ctrl-c to exit) : ";
select region in $(gcloud compute regions list --format='value(name)' 2>/dev/null)
do
    if [ "$region" == "" ]; then
        echo "You must select a Google Cloud Project Region"
    else
        echo "-----------------------------------------------------------------------------"
        echo "Google Cloud Project Region $region selected"
        terraform_variable "cluster_region" "$region" "$GIT_ROOT_DIR" "spinnaker" "$PROJECT"
        terraform_variable "region" "$region" "$GIT_ROOT_DIR" "static_ips" "$PROJECT"
        break;
    fi
done

# choose a zone to place the Halyard and Certbot VMs into
echo "-----------------------------------------------------------------------------"
echo " *****   Google Cloud Project Zone    *****"
echo "-----------------------------------------------------------------------------"
PS3="Enter the number for the Google Cloud Project Zone place the Halyard and Certbot VMs into (ctrl-c to exit) : ";
select zone in $(gcloud compute zones list --format='value(name)' --filter='region='$(gcloud compute regions list --filter="name=$region" --format='value(selfLink)' 2>/dev/null) 2>/dev/null)
do
    if [ "$zone" == "" ]; then
        echo "You must select a Google Cloud Project Zone"
    else
        echo "-----------------------------------------------------------------------------"
        echo "Google Cloud Project Region $zone selected"
        terraform_variable "gcp_zone" "$zone" "$GIT_ROOT_DIR" "halyard" "$PROJECT"
        break;
    fi
done

echo "setting up default values for user inputted values within vault"
# override these for presentation
GOOGLE_OAUTH_CLIENT_ID="${GOOGLE_OAUTH_CLIENT_ID:-replace-me}"
GOOGLE_OAUTH_CLIENT_SECRET="${GOOGLE_OAUTH_CLIENT_SECRET:-replace-me}"
SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN:-replace-me}"
vault write secret/"$PROJECT"/gcp-oauth "client-id=$GOOGLE_OAUTH_CLIENT_ID" "client-secret=$GOOGLE_OAUTH_CLIENT_SECRET" >/dev/null 2>&1
vault write secret/"$PROJECT"/slack-token "value=$SLACK_BOT_TOKEN" >/dev/null 2>&1
echo "-----------------------------------------------------------------------------"
echo " *****   Google Cloud Platform Organization Email Address   *****"
echo "-----------------------------------------------------------------------------"
while [ -z $gcp_admin_email ]; do
    echo -n "Enter an email address of an administrator for your Google Cloud Platform Organization (someone with group administration access):  "
    read gcp_admin_email
done
terraform_variable "gcp_admin_email" "$gcp_admin_email" "$GIT_ROOT_DIR" "halyard" "$PROJECT"
terraform_variable "spingo_user_email" "$USER_EMAIL" "$GIT_ROOT_DIR" "spinnaker" "$PROJECT"
terraform_variable "spingo_user_email" "$USER_EMAIL" "$GIT_ROOT_DIR" "halyard" "$PROJECT"
echo "setup complete"
cd "$CWD"
