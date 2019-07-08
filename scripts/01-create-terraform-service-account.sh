#!/bin/bash

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
    echo -e "terraform {\n backend \"gcs\" {\n bucket = \"$1\" \ncredentials = \"terraform-account.json\" \nprefix = \"$2\" \n} \n}" | terraform fmt - > "$3/$4/override.tf"
    if [ "$?" -ne 0 ]; then
        die "Unable to write terraform backend override file for $4"
    fi
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

vault auth list >/dev/null 2>&1
if [[ "$?" -ne 0 ]]; then
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

DOMAIN="$(gcloud config list account --format 'value(core.account)' 2>/dev/null | cut -d'@' -f2)"
TERRAFORM_REMOTE_GCS_NAME="$PROJECT-tf"
SERVICE_ACCOUNT_NAME="terraform-account"
SERVICE_ACCOUNT_DEST="terraform-account.json"
ONBOARDING_BUCKET="$PROJECT-spinnaker-onboarding"

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

echo "generating keys for $SERVICE_ACCOUNT_NAME"
gcloud iam service-accounts keys create "$SERVICE_ACCOUNT_DEST" \
    --iam-account "$SA_EMAIL"

vault secrets enable -path=secret/"$PROJECT" -default-lease-ttl=0 -max-lease-ttl=0 kv >/dev/null 2>&1

echo "writing $SERVICE_ACCOUNT_DEST to vault in secret/$PROJECT/$SERVICE_ACCOUNT_NAME"
vault write secret/"$PROJECT"/"$SERVICE_ACCOUNT_NAME" "$PROJECT"=@${SERVICE_ACCOUNT_DEST}

echo "create the bucket that will store the Terraform State"
gsutil mb -p "$PROJECT" gs://"$TERRAFORM_REMOTE_GCS_NAME"/
gsutil versioning set on gs://"$TERRAFORM_REMOTE_GCS_NAME"/

echo "create the bucket that will store the onboarding information from teams"
gsutil mb -p "$PROJECT" gs://"$ONBOARDING_BUCKET"/
gsutil versioning set on gs://"$ONBOARDING_BUCKET"/

echo "create custom onboarding bucket IAM role"
gcloud iam roles create onboarding_bucket_role --project "$PROJECT" \
--title "Onboarding Submitter" --description "List and create access for storage objects for use in spinnaker onboarding" \
--permissions storage.objects.list,storage.objects.create  --stage GA

echo "set permissions of onboarding bucket to be creator for domain of $DOMAIN"
gsutil iam ch "domain:$DOMAIN:projects/$PROJECT/roles/onboarding_bucket_role" gs://"$ONBOARDING_BUCKET"

vault read -field "value" secret/"$PROJECT"/keystore-pass >/dev/null 2>&1

if [[ "$?" -ne 0 ]]; then
    echo "-----------------------------------------------------------------------------"
    echo " *****   There is no keystore password stored within vault. Please enter a password you want to use or leave blank to create a random one."
    echo "-----------------------------------------------------------------------------"
    read USER_KEY_PASS
    if [ "$USER_KEY_PASS" == "" ]; then
        echo "creating random keystore password and storing within vault"
        KEY_PASS=$(openssl rand -base64 32)
    else
        echo "storing user defined keystore password within vault"
        KEY_PASS="$USER_KEY_PASS"
    fi
    vault write secret/"$PROJECT"/keystore-pass "value=$KEY_PASS"
fi
cp "$SERVICE_ACCOUNT_DEST" ./spinnaker
cp "$SERVICE_ACCOUNT_DEST" ./halyard
cp "$SERVICE_ACCOUNT_DEST" ./certbot
cp "$SERVICE_ACCOUNT_DEST" ./dns
cp "$SERVICE_ACCOUNT_DEST" ./static_ips
rm "$SERVICE_ACCOUNT_DEST"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "np" "$GIT_ROOT_DIR" "spinnaker"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "np-hal-vm" "$GIT_ROOT_DIR" "halyard"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "np-dns" "$GIT_ROOT_DIR" "dns"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "np-certbot" "$GIT_ROOT_DIR" "certbot"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "np-static-ips" "$GIT_ROOT_DIR" "static_ips"

PROJECT_AUTO_VARS_FILE="var-project.auto.tfvars"
MAIN_PROJECT_AUTO_VARS="$GIT_ROOT_DIR/$PROJECT_AUTO_VARS_FILE"
echo "gcp_project = \"$PROJECT\"" > "$MAIN_PROJECT_AUTO_VARS"
cp "$MAIN_PROJECT_AUTO_VARS" "$GIT_ROOT_DIR/spinnaker/$PROJECT_AUTO_VARS_FILE"
cp "$MAIN_PROJECT_AUTO_VARS" "$GIT_ROOT_DIR/halyard/$PROJECT_AUTO_VARS_FILE"
cp "$MAIN_PROJECT_AUTO_VARS" "$GIT_ROOT_DIR/certbot/$PROJECT_AUTO_VARS_FILE"
cp "$MAIN_PROJECT_AUTO_VARS" "$GIT_ROOT_DIR/static_ips/$PROJECT_AUTO_VARS_FILE"
rm "$MAIN_PROJECT_AUTO_VARS"
echo "bucket_name = \"$PROJECT-halyard-bucket\"" > "$GIT_ROOT_DIR/certbot/var-bucket_name.auto.tfvars"

# enter a wildcard domain to be used
echo "-----------------------------------------------------------------------------"
echo " *****   Managed Domain   *****"
echo "-----------------------------------------------------------------------------"
while [ -z $DOMAIN_TO_MANAGE ]; do
    echo -n "What is the domain to manage for Cloud DNS? (example *.spinnaker.example.com would be spinnaker.example.com)?  "
    read DOMAIN_TO_MANAGE
done
echo "cloud_dns_hostname = \"$DOMAIN_TO_MANAGE\"" > "$GIT_ROOT_DIR/dns/var-cloud_dns_hostname.auto.tfvars"
echo "wildcard_dns_name = \"$DOMAIN_TO_MANAGE\"" > "$GIT_ROOT_DIR/certbot/var-wildcard_dns_name.auto.tfvars"
echo "cloud_dns_hostname = \"$DOMAIN_TO_MANAGE\"" > "$GIT_ROOT_DIR/spinnaker/var-cloud_dns_hostname.auto.tfvars"
echo "cloud_dns_hostname = \"$DOMAIN_TO_MANAGE\"" > "$GIT_ROOT_DIR/halyard/var-cloud_dns_hostname.auto.tfvars"

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
        echo "managed_dns_gcp_project = \"$dns_project\"" > "$GIT_ROOT_DIR/spinnaker/var-managed_dns_gcp_project.auto.tfvars"
        echo "gcp_project = \"$dns_project\"" > "$GIT_ROOT_DIR/dns/var-gcp_project.auto.tfvars"
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
        echo "cluster_region = \"$region\"" > "$GIT_ROOT_DIR/spinnaker/var-cluster_region.auto.tfvars"
        echo "region = \"$region\"" > "$GIT_ROOT_DIR/static_ips/var-region.auto.tfvars"
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
        echo "gcp_zone = \"$zone\"" > "$GIT_ROOT_DIR/certbot/var-gcp_zone.auto.tfvars"
        echo "gcp_zone = \"$zone\"" > "$GIT_ROOT_DIR/halyard/var-gcp_zone.auto.tfvars"
        break;
    fi
done

echo "setting up default values for user inputted values within vault"
vault write secret/"$PROJECT"/gcp-oauth "client-id=replace-me" "client-secret=replace-me" >/dev/null 2>&1
vault write secret/"$PROJECT"/slack-token "value=replace-me" >/dev/null 2>&1
echo "-----------------------------------------------------------------------------"
echo " *****   Google Cloud Platform Organization Email Address   *****"
echo "-----------------------------------------------------------------------------"
while [ -z $gcp_admin_email ]; do
    echo -n "Enter an email address of an administrator for your Google Cloud Platform Organization (someone with group administration access):  "
    read gcp_admin_email
done
echo "gcp_admin_email = \"$gcp_admin_email\"" > "$GIT_ROOT_DIR/halyard/var-gcp_admin_email.auto.tfvars"
echo "setup complete"
cd "$CWD"
