#!/bin/bash 

# Change this to match the specific onboarding bucket name for your project
ONBOARDING_BUCKET_NAME="np-platforms-cd-thd-spinnaker-onboarding"


# Inspired by: https://stackoverflow.com/questions/42170380/how-to-add-users-to-kubernetes-kubectl
# this script creates a service account (spinnaker-user) on a Kubernetes cluster (tested with AWS EKS 1.9)
# prereqs: a kubectl ver 1.10 installed and proper configuration of the heptio authenticator
# this has been tested on Linux in a Cloud9 environment (for MacOS the syntax may be slightly different)

echo    "########################################################################"
echo    "This script will create a new 'spinnaker' GCP service account with"
echo    "needed permissions to Google AppEngine and upload the credentials"
echo    "to a bucket for use by spinnaker"
echo -e "########################################################################\n\n"


####################################################
########             Dependencies           ######## 
####################################################

# ensure that the required commands are present needed to run this script
die() { echo "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "gsutil"
need "gcloud"

####################################################
########           Create an account        ######## 
####################################################

echo -e "Getting current gcloud project configured\n"
PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
echo -e "Current project is : $PROJECT \n"

SERVICE_ACCOUNT_NAME="spinnaker-gae-sa"
SERVICE_ACCOUNT_FILE="${PROJECT}-${SERVICE_ACCOUNT_NAME}.json"

gcloud iam service-accounts create \
    "$SERVICE_ACCOUNT_NAME" \
    --display-name "$SERVICE_ACCOUNT_NAME"

SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:${SERVICE_ACCOUNT_NAME}" \
    --format='value(email)')

if [[ -z "$SA_EMAIL" ]]; then
    echo -e "Unable to retreive service account email, cannot continue\n"
    exit 1
fi

gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/storage.admin'

gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/appengine.appAdmin'

gcloud --no-user-output-enabled \
    iam service-accounts keys create "$SERVICE_ACCOUNT_FILE" \
    --iam-account "$SA_EMAIL"


# TODO: check proper permissions for appengine
# echo -e "Getting current roles that have GKE Cluster Admin Access \n"
# CLUSTER_ADMIN_GROUPS=$(gcloud projects get-iam-policy "$PROJECT" --flatten="bindings[].members" --format="json" --filter="bindings.role:roles/container.clusterAdmin" 2>/dev/null | jq -r '.[].bindings.members' - | grep 'group:' | awk -F '[@:]' '{print $2}')
# INDENTED_CLUSTER_ADMIN_GROUPS=$(echo "$CLUSTER_ADMIN_GROUPS" | sed 's/^/    - /')

# Append metadata
# echo "spinnaker-metadata:" >> "$CONFIG_FILE"
# echo "  project: $PROJECT" >> "$CONFIG_FILE"
# echo "  requestor: $CURRENT_USER_ACCOUNT" >> "$CONFIG_FILE"
# echo "  groups:" >> "$CONFIG_FILE"
# echo "$INDENTED_CLUSTER_ADMIN_GROUPS" >> "$CONFIG_FILE"

USER_EMAIL=$(gcloud config list account --format "value(core.account)")

# Append metadata object into service account credentials file.
cat $SERVICE_ACCOUNT_FILE | jq '. += {"metadata":{"requester_email":"'$USER_EMAIL'","project":"'$PROJECT'","groups":["TODO"]}}' > $SERVICE_ACCOUNT_FILE

# Create boto file and set path to ensure reliable gsutil operations if the user already has gsutil configurations
cat <<EOF >> boto
[Boto]
https_validate_certificates = True
[GSUtil]
content_language = en
default_api_version = 2
EOF
export BOTO_CONFIG=boto

ONBOARDING_FULL_DESTINATION="$ONBOARDING_BUCKET_NAME/gae/$PROJECT/"

gsutil cp "$SERVICE_ACCOUNT_FILE" gs://"$ONBOARDING_FULL_DESTINATION" && rm "$SERVICE_ACCOUNT_FILE"

# Cleanup boto config
rm -f boto
unset BOTO_CONFIG

echo -e "\n\nThe creation of the service account is complete"
