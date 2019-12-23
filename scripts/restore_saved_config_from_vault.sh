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

# can also run "gcloud config list --format 'value(core.project)' 2>/dev/null" to get the project name dynamically
PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
# DNS_PROJECT=$(vault read -field value secret/"$PROJECT"/dns_project_name)
SERVICE_ACCOUNT_NAME="terraform-account"
# DNS_SERVICE_ACCOUNT_NAME="terraform-account-dns"

vault read -field "$PROJECT" secret/"$PROJECT"/"$SERVICE_ACCOUNT_NAME" > "$SERVICE_ACCOUNT_NAME".json
# vault read -field "$DNS_PROJECT" secret/"$DNS_PROJECT"/"$SERVICE_ACCOUNT_NAME" > "$DNS_SERVICE_ACCOUNT_NAME".json
cp "$SERVICE_ACCOUNT_NAME".json ./halyard
cp "$SERVICE_ACCOUNT_NAME".json ./spinnaker
cp "$SERVICE_ACCOUNT_NAME".json ./static_ips
cp "$SERVICE_ACCOUNT_NAME".json ./dns
# cp "$DNS_SERVICE_ACCOUNT_NAME".json ./dns/"$SERVICE_ACCOUNT_NAME".json

# For overrides.tf
vault read -field value secret/"$PROJECT"/local-override-np-hal-vm > halyard/override.tf
vault read -field value secret/"$PROJECT"/local-override-np-dns > dns/override.tf
vault read -field value secret/"$PROJECT"/local-override-np > spinnaker/override.tf
vault read -field value secret/"$PROJECT"/local-override-np-static-ips > static_ips/override.tf

# GCP Project name
vault read -field value secret/"$PROJECT"/local-vars-spinnaker-gcp_project > spinnaker/var-gcp_project.auto.tfvars
vault read -field value secret/"$PROJECT"/local-vars-halyard-gcp_project > halyard/var-gcp_project.auto.tfvars
vault read -field value secret/"$PROJECT"/local-vars-static_ips-gcp_project > static_ips/var-gcp_project.auto.tfvars
vault read -field value secret/"$PROJECT"/local-vars-monitoring-alerting-gcp_project > monitoring-alerting/var-gcp_project.auto.tfvars

# For DNS domain to manage
vault read -field value secret/"$PROJECT"/local-vars-dns-cloud_dns_hostname > dns/var-cloud_dns_hostname.auto.tfvars
vault read -field value secret/"$PROJECT"/local-vars-spinnaker-cloud_dns_hostname > spinnaker/var-cloud_dns_hostname.auto.tfvars
vault read -field value secret/"$PROJECT"/local-vars-halyard-cloud_dns_hostname > halyard/var-cloud_dns_hostname.auto.tfvars

# For DNS project
vault read -field value secret/"$PROJECT"/local-vars-spinnaker-managed_dns_gcp_project > spinnaker/var-managed_dns_gcp_project.auto.tfvars
vault read -field value secret/"$PROJECT"/local-vars-dns-gcp_project > dns/var-gcp_project.auto.tfvars

# For cluster region
vault read -field value secret/"$PROJECT"/local-vars-spinnaker-cluster_region > spinnaker/var-cluster_region.auto.tfvars
vault read -field value secret/"$PROJECT"/local-vars-static_ips-region > static_ips/var-region.auto.tfvars

# For halyard VM zone
vault read -field value secret/"$PROJECT"/local-vars-halyard-gcp_zone > halyard/var-gcp_zone.auto.tfvars

# For GCP Org Admin Email
vault read -field value secret/"$PROJECT"/local-vars-halyard-gcp_admin_email > halyard/var-gcp_admin_email.auto.tfvars
vault read -field value secret/"$PROJECT"/local-vars-halyard-spingo_user_email > spinnaker/var-spingo_user_email.auto.tfvars
vault read -field value secret/"$PROJECT"/local-vars-halyard-spingo_user_email > halyard/var-spingo_user_email.auto.tfvars

cd "$CWD" || { echo "failed to return to directory $CWD"; exit;}
