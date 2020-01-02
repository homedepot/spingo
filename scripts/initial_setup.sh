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
    command -v "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "vault"
need "gcloud"
need "openssl"
need "git"
need "cut"
need "jq"

CWD=$(pwd)
GIT_ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT_DIR" || { echo "failed to change directory to $GIT_ROOT_DIR exiting"; exit 1; }

# shellcheck source=scripts/common.sh
# shellcheck disable=SC1091
source "$GIT_ROOT_DIR"/scripts/common.sh

terraform_override() {
    # $1 = terraform bucket name
    # $2 = terraform backend prefix
    # $3 = git root directory
    # $4 = terraform sub-project directory
    # $5 = GCP project name

    if ! echo -e "terraform {\n backend \"gcs\" {\n bucket = \"$1\" \ncredentials = \"terraform-account.json\" \nprefix = \"$2\" \n} \n}" | terraform fmt - > "$3/$4/override.tf"
    then
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

    echo -e "$1 = \"${2}\"" > "$3/$4/var-$1.auto.tfvars"
    vault write "secret/$5/local-vars-$4-$1" "value"=@"$3/$4/var-$1.auto.tfvars" >/dev/null 2>&1
}

prompt_to_use_base_hostname_for_deck_or_get_value(){
    # $1 = cluster index number
    # $2 = attribute key name from default cluster config json
    # $3 = git root directory
    # $4 = user readable name for value
    # $5 = cluster name
    # $6 = is base hostname use available
    # $7 = base hostname chosen by user stored at DOMAIN_TO_MANAGE
    # $8 = current SHIP_PLANS_JSON content
    RETURN_VALUE=""
    if [ "$6" == "true" ]; then
        echoerr "-----------------------------------------------------------------------------"
        echoerr " *****   There can be only one deployment that can use the base hostname $7 as it's hostname for it's UI (deck) *****"
        echoerr "-----------------------------------------------------------------------------"
        PS3="Do you want this deployment $5 to use the base hostname for deck or just press [ENTER] to choose the default (No) : "
        PROMPT_VALUE=$(select_with_default "No" "Yes")
        if [ "$PROMPT_VALUE" == "Yes" ]; then
            RETURN_VALUE=""
        else
            while [ -z "$RETURN_VALUE" ]; do
                RETURN_VALUE="$(prompt_for_value_with_default "$1" "$2" "$3" "$4" "$5")"
                HOSTNAME_USED="$(check_for_hostname_used "$8" "$RETURN_VALUE")"
                if [ "$HOSTNAME_USED" == "true" ]; then
                    echoerr "A hostname can only be used once per project and $RETURN_VALUE has already been used, please choose another hostname"
                    RETURN_VALUE=""
                fi
            done
        fi
    else
        while [ -z "$RETURN_VALUE" ]; do
            RETURN_VALUE="$(prompt_for_value_with_default "$1" "$2" "$3" "$4" "$5")"
            HOSTNAME_USED="$(check_for_hostname_used "$8" "$RETURN_VALUE")"
            if [ "$HOSTNAME_USED" == "true" ]; then
                echoerr "A hostname can only be used once per project and $RETURN_VALUE has already been used, please choose another hostname"
                RETURN_VALUE=""
            fi
        done
    fi
    echo "$RETURN_VALUE"
}

prompt_for_value_with_default() {
    # $1 = cluster index number
    # $2 = attribute key name from default cluster config json
    # $3 = git root directory
    # $4 = user readable name for value
    # $5 = cluster name

    OPTIONAL_CLUSTER_NAME=""
    if [ -z "$5" ]; then
        OPTIONAL_CLUSTER_NAME="Cluster $5 "
    fi
    READ_PROMPT_BASE="Enter the $4 for #$1 ${OPTIONAL_CLUSTER_NAME}and press [ENTER]"
    while [ -z "$PROMPT_VALUE" ]; do
        DEFAULT_PROMPT_VALUE=$(< "${3}/scripts/default_cluster_config.json" jq -r '.ship_plans as $plans | .ship_plans | to_entries['"$1"'-1] | .key as $the_key | $plans | .[$the_key].'"$2"'' 2>/dev/null)
        echoerr "-----------------------------------------------------------------------------"
        DEFAULT_CHOICE_PROMPT=" or just press [ENTER] for the default (${DEFAULT_PROMPT_VALUE})"
        if [ -z "$DEFAULT_PROMPT_VALUE" ]; then
            READ_PROMPT="$READ_PROMPT_BASE"":"
        else
            READ_PROMPT="$READ_PROMPT_BASE""$DEFAULT_CHOICE_PROMPT"":"
        fi
        echoerr "$READ_PROMPT"  >&2
        read -r PROMPT_VALUE
        PROMPT_VALUE="${PROMPT_VALUE:-$DEFAULT_PROMPT_VALUE}"
        if [ -z "$PROMPT_VALUE" ]; then 
            echoerr "You must enter a $4"
        else
            echoerr "-----------------------------------------------------------------------------"
            echoerr "Entered $4 is $PROMPT_VALUE"
        fi
    done
    echo "$PROMPT_VALUE"

}

check_for_base_hostname_used() {
    RESULT=$(echo "$1" | jq '.ship_plans | to_entries | .[].value | select(.deckSubdomain == "") | .deckSubdomain == ""')
    if [ "$RESULT" == "true" ]; then
        echo "false"
    else
        echo "true"
    fi
}

check_for_hostname_used() {
    # $1 = current SHIP_PLANS_JSON content
    # $2 = hostname to check if already used

    # returns true when there are no subdomains that match the hostname to check
    if echo "$1" | jq --arg hn "$2" '.ship_plans | to_entries | .[].value | to_entries | map(select(.key | match("subdomain";"i"))) | .[] | select(.value == $hn) | .value == $hn' | grep "true"; then
        echo "true"
    else
        echo "false"
    fi
}

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

echo "Enabling required Google Cloud APIs. This could take several minutes."
echo "enabling compute.googleapis.com service"
gcloud services enable compute.googleapis.com

VAULT_RESPONSE=$(vault status -format json | jq -r '. | select(.initialized == true and .sealed == false) | .initialized')
if [[ "$VAULT_RESPONSE" != "true" ]]; then
  echo "not logged into vault!"
  echo "1. set VAULT_ADDR (e.g. 'export VAULT_ADDR=https://vault.example.com:10231')"
  echo "2. login: (e.g. 'vault login <some token>')"
  exit 1
fi

USER_EMAIL="$(gcloud config list --format 'value(core.account)')"
TERRAFORM_REMOTE_GCS_NAME="$PROJECT-tf"
SERVICE_ACCOUNT_NAME="terraform-account"
SERVICE_ACCOUNT_DEST="terraform-account.json"

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

if ! vault read -field "value" secret/"$PROJECT"/keystore-pass >/dev/null 2>&1
  then
    echo "-----------------------------------------------------------------------------"
    echo " *****   There is no keystore password stored within vault. Please enter a password you want to use or leave blank to create a random one."
    echo "-----------------------------------------------------------------------------"
    read -r USER_KEY_PASS
    if [ "$USER_KEY_PASS" == "" ]; then
        echo "creating random keystore password and storing within vault"
        KEY_PASS=$(openssl rand -base64 29 | tr -d "=+/" | cut -c1-25)
    else
        echo "storing user defined keystore password within vault"
        KEY_PASS="$USER_KEY_PASS"
    fi
    vault write secret/"$PROJECT"/keystore_pass "value=$KEY_PASS"
fi

terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "spingo-spinnaker" "$GIT_ROOT_DIR" "spinnaker" "$PROJECT"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "spingo-halyard" "$GIT_ROOT_DIR" "halyard" "$PROJECT"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "spingo-dns" "$GIT_ROOT_DIR" "dns" "$PROJECT"
terraform_override "$TERRAFORM_REMOTE_GCS_NAME" "spingo-static-ips" "$GIT_ROOT_DIR" "static_ips" "$PROJECT"
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
while [ -z "$DOMAIN_TO_MANAGE" ]; do
    echo -n "What is the domain to manage for Cloud DNS? (example *.spinnaker.example.com would be spinnaker.example.com)?  "
    read -r DOMAIN_TO_MANAGE
done

terraform_variable "cloud_dns_hostname" "$DOMAIN_TO_MANAGE" "$GIT_ROOT_DIR" "dns" "$PROJECT"
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
        echo "Managed DNS Google Cloud Project selected : $dns_project"
        terraform_variable "managed_dns_gcp_project" "$dns_project" "$GIT_ROOT_DIR" "spinnaker" "$PROJECT"
        terraform_variable "gcp_project" "$dns_project" "$GIT_ROOT_DIR" "dns" "$PROJECT"
        vault write "secret/$PROJECT/dns_project_name" "value=$dns_project" >/dev/null 2>&1
        break;
    fi
done

# choose how many clusters to create
echo "-----------------------------------------------------------------------------"
echo " *****   How Many Spinnaker Deployments?   *****"
echo "-----------------------------------------------------------------------------"
PS3="Enter the number of Spinnaker Deployments to create inside project $PROJECT (choose the number for Exit to exit) : ";
select cluster_count in 1 2 3 4 Exit
do
    if [ "$cluster_count" == "" ]; then
        echo "You must select a Managed DNS GCP Project"
    elif [ "$cluster_count" == "Exit" ]; then
        echo "Exiting at user request"
        exit 1
    else
        echo "-----------------------------------------------------------------------------"
        echo "Number of Spinnaker Deployments selected : $cluster_count"
        SELECTED_CLUSTER_COUNT=$cluster_count
        break;
    fi
done
SHIP_PLANS_JSON="$(< "$GIT_ROOT_DIR"/scripts/empty_cluster_config.json)"
n=1
until [ $n -gt $SELECTED_CLUSTER_COUNT ]
do
    echo "-----------------------------------------------------------------------------"
    echo " *****   Cluster name for #$n  *****"
    CLUSTER_NAME="$(prompt_for_value_with_default "$n" "clusterPrefix" "$GIT_ROOT_DIR" "cluster name")"
    CLUSTER_REGION=""
    while [ -z "$CLUSTER_REGION" ]; do
        # choose a region to place the cluster into
        echo "-----------------------------------------------------------------------------"
        echo " *****   Google Cloud Project Region for Cluster $CLUSTER_NAME   *****"
        echo "-----------------------------------------------------------------------------"
        DEFAULT_CLUSTER_REGION="$(< "${GIT_ROOT_DIR}/scripts/default_cluster_config.json" jq -r '.ship_plans as $plans | .ship_plans | to_entries['"$n"'-1] | .key as $the_key | $plans | .[$the_key].clusterRegion' 2>/dev/null)"
        READ_PROMPT_BASE="Enter the number for the Cluster Region for #$n and press [ENTER]"
        DEFAULT_CHOICE_PROMPT=" or just press [ENTER] for the default (${DEFAULT_CLUSTER_REGION})(ctrl-c to exit)"
        if [ -z "$DEFAULT_CLUSTER_REGION" ]; then
            READ_PROMPT="$READ_PROMPT_BASE"" : "
        else
            READ_PROMPT="$READ_PROMPT_BASE""$DEFAULT_CHOICE_PROMPT"" : "
        fi
        PS3="$READ_PROMPT";
        CLUSTER_REGION="$(select_with_default "$(gcloud compute regions list --format='value(name)' 2>/dev/null)")"
        CLUSTER_REGION="${CLUSTER_REGION:-$DEFAULT_CLUSTER_REGION}"
    done
    echo "-----------------------------------------------------------------------------"
    echo "Google Cloud Project Region $CLUSTER_REGION selected for Cluster $CLUSTER_NAME"
    SHIP_PLANS_JSON="$(echo "$SHIP_PLANS_JSON" | jq --arg nm "$CLUSTER_NAME" --arg dsh "-" --arg reg "$CLUSTER_REGION" '. | .ship_plans += { ($nm + $dsh + $reg): { } }')"
    echo "NEW SHIP_PLANS_JSON : "$(echo $SHIP_PLANS_JSON | jq '.')""
    echo "-----------------------------------------------------------------------------"
    echo " *****   The subdomain for deck is the address where users will go to interact with Spinnaker in a browser"
    DECK_SUBDOMAIN="$(prompt_to_use_base_hostname_for_deck_or_get_value "$n" "deckSubdomain" "$GIT_ROOT_DIR" "deck subdomain" "$CLUSTER_NAME" "$(check_for_base_hostname_used "$SHIP_PLANS_JSON")" "$DOMAIN_TO_MANAGE" "$SHIP_PLANS_JSON")"
    SHIP_PLANS_JSON=$(echo "$SHIP_PLANS_JSON" | jq --arg nm "$CLUSTER_NAME" --arg dsh "-" --arg reg "$CLUSTER_REGION" --arg dk "$DECK_SUBDOMAIN" '. | .ship_plans += { ($nm + $dsh + $reg): { deckSubdomain: $dk } }')
    echo "NEW SHIP_PLANS_JSON : "$(echo $SHIP_PLANS_JSON | jq '.')""
    echo "-----------------------------------------------------------------------------"
    echo " *****   The subdomain for gate is the address where webhooks like those that come from GitHub will use"
    while [ -z "$GATE_SUBDOMAIN" ]; do
        GATE_SUBDOMAIN="$(prompt_for_value_with_default "$n" "gateSubdomain" "$GIT_ROOT_DIR" "gate subdomain" "$CLUSTER_NAME")"
        HOSTNAME_USED=$(check_for_hostname_used "$SHIP_PLANS_JSON" "$GATE_SUBDOMAIN")
        if [ "$HOSTNAME_USED" == "true" ]; then
            echoerr "A hostname can only be used once per project and $GATE_SUBDOMAIN has already been used, please choose another hostname"
            GATE_SUBDOMAIN=""
        fi
    done
    SHIP_PLANS_JSON=$(echo "$SHIP_PLANS_JSON" | jq --arg nm "$CLUSTER_NAME" --arg dsh "-" --arg reg "$CLUSTER_REGION" --arg dk "$DECK_SUBDOMAIN" --arg gt "$GATE_SUBDOMAIN" '. | .ship_plans += { ($nm + $dsh + $reg): { deckSubdomain: $dk, gateSubdomain: $gt } }')
    echo "NEW SHIP_PLANS_JSON : "$(echo $SHIP_PLANS_JSON | jq '.')""
    echo "-----------------------------------------------------------------------------"
    echo " *****   The subdomain for x509 is the address where automation like the spin CLI will use"
    while [ -z "$X509_SUBDOMAIN" ]; do
        X509_SUBDOMAIN="$(prompt_for_value_with_default "$n" "x509Subdomain" "$GIT_ROOT_DIR" "gate x509 subdomain" "$CLUSTER_NAME")"
        HOSTNAME_USED=$(check_for_hostname_used "$SHIP_PLANS_JSON" "$X509_SUBDOMAIN")
        if [ "$HOSTNAME_USED" == "true" ]; then
            echoerr "A hostname can only be used once per project and $X509_SUBDOMAIN has already been used, please choose another hostname"
            X509_SUBDOMAIN=""
        fi
    done
    SHIP_PLANS_JSON=$(echo "$SHIP_PLANS_JSON" | jq --arg nm "$CLUSTER_NAME" --arg dsh "-" --arg reg "$CLUSTER_REGION" --arg dk "$DECK_SUBDOMAIN" --arg gt "$GATE_SUBDOMAIN" --arg x509 "$X509_SUBDOMAIN" '. | .ship_plans += { ($nm + $dsh + $reg): { deckSubdomain: $dk, gateSubdomain: $gt, x509Subdomain: $x509 } }')
    echo "NEW SHIP_PLANS_JSON : "$(echo $SHIP_PLANS_JSON | jq '.')""
    echo "-----------------------------------------------------------------------------"
    echo " *****   The subdomain for vault is the address where the vault server will be setup for accessing secrets"
    while [ -z "$VAULT_SUBDOMAIN" ]; do
        VAULT_SUBDOMAIN="$(prompt_for_value_with_default "$n" "vaultSubdomain" "$GIT_ROOT_DIR" "vault subdomain" "$CLUSTER_NAME")"
        HOSTNAME_USED=$(check_for_hostname_used "$SHIP_PLANS_JSON" "$VAULT_SUBDOMAIN")
        if [ "$HOSTNAME_USED" == "true" ]; then
            echoerr "A hostname can only be used once per project and $VAULT_SUBDOMAIN has already been used, please choose another hostname"
            VAULT_SUBDOMAIN=""
        fi
    done
    SHIP_PLANS_JSON=$(echo "$SHIP_PLANS_JSON" | jq --arg nm "$CLUSTER_NAME" --arg dsh "-" --arg reg "$CLUSTER_REGION" --arg dk "$DECK_SUBDOMAIN" --arg gt "$GATE_SUBDOMAIN" --arg x509 "$X509_SUBDOMAIN" --arg vlt "$VAULT_SUBDOMAIN" --arg wd "$DOMAIN_TO_MANAGE" '. | .ship_plans += { ($nm + $dsh + $reg): { deckSubdomain: $dk, gateSubdomain: $gt, x509Subdomain: $x509, vaultSubbdomain: $vlt, wildcardDomain: $wd } }')
    echo "NEW SHIP_PLANS_JSON : "$(echo $SHIP_PLANS_JSON | jq '.')""
    n=$((n+1))
done

terraform_variable "region" "$CLUSTER_REGION" "$GIT_ROOT_DIR" "static_ips" "$PROJECT"
echo "$SHIP_PLANS_JSON" > "$GIT_ROOT_DIR"/static_ips/var-ship_plans.auto.tfvars.json
vault write "secret/$PROJECT/local-vars-static_ips-ship_plans" "value"=@"$GIT_ROOT_DIR/static_ips/var-ship_plans.auto.tfvars.json" >/dev/null 2>&1

# choose a zone to place the Halyard VMs into
echo "-----------------------------------------------------------------------------"
echo " *****   Google Cloud Project Zone    *****"
echo "-----------------------------------------------------------------------------"
PS3="Enter the number for the Google Cloud Project Zone to place the Halyard VM into (ctrl-c to exit) : ";
select zone in $(gcloud compute zones list --format='value(name)' --filter='region='"$(gcloud compute regions list --filter="name=$CLUSTER_REGION" --format='value(selfLink)' 2>/dev/null)" 2>/dev/null)
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

GOOGLE_OAUTH_CLIENT_ID="$(prompt_for_value \
    "$GOOGLE_OAUTH_CLIENT_ID" \
    "Google OAuth Client ID" \
    "What is the Google OAuth Client ID? : " \
    "Setup using instructions found here https://github.com/homedepot/spingo#google-oauth-authentication-setup")"
GOOGLE_OAUTH_CLIENT_SECRET="$(prompt_for_value \
    "$GOOGLE_OAUTH_CLIENT_SECRET" \
    "Google OAuth Client Secret" \
    "What is the Google OAuth Client Secret? : " \
    "Setup using instructions found here https://github.com/homedepot/spingo#google-oauth-authentication-setup")"

echoerr "-----------------------------------------------------------------------------"
echoerr " *****   Halyard Auto Quickstart ***** Auto Quickstart sets up the Spinnaker(s) as soon as the Halyard VM starts up the fist time"
echoerr "-----------------------------------------------------------------------------"
PS3="Do you want to enable halyard auto initial quickstart or just press [ENTER] to use default (Yes) ? : "
AUTO_QUICKSTART_HALYARD="$(select_with_default "No" "Yes")"
AUTO_QUICKSTART_HALYARD=${AUTO_QUICKSTART_HALYARD:-Yes}
if [ "$AUTO_QUICKSTART_HALYARD" == "Yes" ]; then
    terraform_variable "auto_start_halyard_quickstart" "true" "$GIT_ROOT_DIR" "halyard" "$PROJECT"
else
    terraform_variable "auto_start_halyard_quickstart" "false" "$GIT_ROOT_DIR" "halyard" "$PROJECT"
fi

if [ -z "$SLACK_BOT_TOKEN" ]; then
    PS3="Do you want to setup Slack automatically and already have a token or just press [ENTER] for (No)? : "
    USE_SLACK=$(select_with_default "No" "Yes")
    USE_SLACK=${USE_SLACK:-No}
    if [ "$USE_SLACK" == "No" ]; then
        SLACK_BOT_TOKEN=$(prompt_for_value \
        "" \
        "Slack Bot Token" \
        "What is your Slack Bot Token?" \
        "Setup using instructions found here https://github.com/homedepot/spingo#if-you-are-going-to-use-slack-integration-skip-to-next-section-if-not")
    else
        SLACK_BOT_TOKEN="no-slack"
    fi
else
    echo "Found Slack Bot Token in environment variable so moving on"
fi

vault write secret/"$PROJECT"/gcp-oauth "client-id=$GOOGLE_OAUTH_CLIENT_ID" "client-secret=$GOOGLE_OAUTH_CLIENT_SECRET" >/dev/null 2>&1
vault write secret/"$PROJECT"/slack-token "value=$SLACK_BOT_TOKEN" >/dev/null 2>&1
echo "-----------------------------------------------------------------------------"
echo " *****   Google Cloud Platform Organization Email Address   *****"
echo "-----------------------------------------------------------------------------"
while [ -z "$gcp_admin_email" ]; do
    echo -n "Enter an email address of an administrator for your Google Cloud Platform Organization (someone with group administration access):  "
    read -r gcp_admin_email
done
terraform_variable "gcp_admin_email" "$gcp_admin_email" "$GIT_ROOT_DIR" "halyard" "$PROJECT"
terraform_variable "spingo_user_email" "$USER_EMAIL" "$GIT_ROOT_DIR" "spinnaker" "$PROJECT"
terraform_variable "spingo_user_email" "$USER_EMAIL" "$GIT_ROOT_DIR" "halyard" "$PROJECT"



echo "Enabling required Google Cloud APIs. This could take several minutes."
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
echo "enabling cloudkms.googleapis.com - Needed for Vault"
gcloud services enable cloudkms.googleapis.com

echo "creating $SERVICE_ACCOUNT_NAME service account"
SA_EMAIL="$(gcloud iam service-accounts list \
      --filter="displayName:${SERVICE_ACCOUNT_NAME}" \
      --format='value(email)')"
if [ -n "$SA_EMAIL" ]; then
    echo "Service account $SERVICE_ACCOUNT_NAME already exists so no need to create it"
else
    gcloud iam service-accounts create \
        "$SERVICE_ACCOUNT_NAME" \
        --display-name "$SERVICE_ACCOUNT_NAME"
fi

while [ -z "$SA_EMAIL" ]; do
  echo "waiting for service account to be fully created..."
  sleep 1
  SA_EMAIL="$(gcloud iam service-accounts list \
      --filter="displayName:${SERVICE_ACCOUNT_NAME}" \
      --format='value(email)')"
done

echo "adding roles to $SERVICE_ACCOUNT_NAME for $SA_EMAIL"

roles=(
    'roles/storage.admin'
    'roles/resourcemanager.projectIamAdmin'
    'roles/iam.serviceAccountAdmin'
    'roles/iam.serviceAccountKeyAdmin'
    'roles/compute.admin'
    'roles/container.admin'
    'roles/iam.serviceAccountUser'
    'roles/dns.admin'
    'roles/redis.admin'
    'roles/cloudsql.admin'
    'roles/monitoring.admin'
    'roles/iam.roleAdmin'
    'roles/pubsub.admin'
    'roles/cloudkms.admin'
)

EXISTING_ROLES="$(gcloud projects get-iam-policy "$PROJECT" --flatten="bindings[].members" --format="json" --filter="bindings.members:$SA_EMAIL" | jq -r '.[].bindings' | jq -s '.')"

for role in "${roles[@]}"; do
    EXISTING_ROLE_CHECK="$(echo "$EXISTING_ROLES" | jq -r --arg rl "$role" '.[] | select(.role == $rl) | .role')"
    if [ -z "$EXISTING_ROLE_CHECK" ]; then
        echo "Attempting to add role $role to service account $SERVICE_ACCOUNT_NAME"
        
        if gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
            --member serviceAccount:"$SA_EMAIL" \
            --role="$role"; then
            echo "Unable to add role $role to service account $SERVICE_ACCOUNT_NAME"
        else
            echo "Added role $role to service account $SERVICE_ACCOUNT_NAME"
        fi
    else
        echo "Role $role already exists on service account $SERVICE_ACCOUNT_NAME so nothing to add"
    fi
done

vault secrets enable -path=secret/"$PROJECT" -default-lease-ttl=0 -max-lease-ttl=0 kv >/dev/null 2>&1

EXISTING_KEY="$(vault read -field="$PROJECT" "secret/$PROJECT/$SERVICE_ACCOUNT_NAME")"
if [ -z "$EXISTING_KEY" ]; then
    echo "generating keys for $SERVICE_ACCOUNT_NAME"
    gcloud iam service-accounts keys create "$SERVICE_ACCOUNT_DEST" \
        --iam-account "$SA_EMAIL"
    echo "writing $SERVICE_ACCOUNT_DEST to vault in secret/$PROJECT/$SERVICE_ACCOUNT_NAME"
    vault write secret/"$PROJECT"/"$SERVICE_ACCOUNT_NAME" "$PROJECT"=@${SERVICE_ACCOUNT_DEST}
else
    echo "key already exists in vault for $SERVICE_ACCOUNT_NAME so no need to create it again"
    echo "$EXISTING_KEY" > "$SERVICE_ACCOUNT_DEST"
fi

cp "$SERVICE_ACCOUNT_DEST" ./spinnaker
cp "$SERVICE_ACCOUNT_DEST" ./halyard
cp "$SERVICE_ACCOUNT_DEST" ./dns
cp "$SERVICE_ACCOUNT_DEST" ./static_ips
cp "$SERVICE_ACCOUNT_DEST" ./monitoring-alerting
rm "$SERVICE_ACCOUNT_DEST"

echo "setup complete"
cd "$CWD" || { echo "failed to return to $CWD" ; exit ; }
