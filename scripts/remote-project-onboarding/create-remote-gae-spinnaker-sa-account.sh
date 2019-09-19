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

bold() {
  echo ". $(tput bold)" "$*" "$(tput sgr0)";
}

# ensure that the required commands are present needed to run this script
die() { echo "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "gsutil"
need "gcloud"
need "tput"
need "jq"

####################################################
########           Create an account        ######## 
####################################################

echo -e "Getting current gcloud project configured\n"
PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
echo -e "Current project is : $PROJECT \n"

SERVICE_ACCOUNT_NAME="spinnaker-gae-sa"
SERVICE_ACCOUNT_FILE="${PROJECT}-${SERVICE_ACCOUNT_NAME}.json"


SA_EMAIL=$(gcloud iam service-accounts --project "$PROJECT" list \
  --filter="displayName:$SERVICE_ACCOUNT_NAME" \
  --format='value(email)')

if [ -z "$SA_EMAIL" ]; then
  bold "Creating service account $SERVICE_ACCOUNT_NAME..."

  gcloud iam service-accounts --project "$PROJECT" create \
    "$SERVICE_ACCOUNT_NAME" \
    --display-name "$SERVICE_ACCOUNT_NAME"

  while [ -z "$SA_EMAIL" ]; do
    echo "waiting for service account to be fully created..."
    sleep 1
    SA_EMAIL=$(gcloud iam service-accounts --project "$PROJECT" list \
      --filter="displayName:$SERVICE_ACCOUNT_NAME" \
      --format='value(email)')
  done
else
  bold "Using existing service account $SERVICE_ACCOUNT_NAME..."
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


echo -e "Getting current roles that have App Engine Admin access \n"
APPENGINE_ADMIN_GROUPS=$(gcloud projects get-iam-policy "$PROJECT" --flatten="bindings[].members" --format="json" --filter="bindings.role:roles/appengine.appAdmin" 2>/dev/null | jq -r '.[].bindings.members' - | grep 'group:' | awk -F '[@:]' 'BEGIN { ORS=" " }; {print $2}')
USER_EMAIL=$(gcloud config list account --format "value(core.account)")

# Append metadata object into service account credentials file.
jq '. += {"metadata":{"requester_email":"'$USER_EMAIL'","project":"'$PROJECT'","groups":[]}}' $SERVICE_ACCOUNT_FILE > "credentials.tmp" && mv "credentials.tmp" $SERVICE_ACCOUNT_FILE

# Append each group in the role binding to the credentials metadata > groups array.
# There might be a more elegant way to do this. Editing json and writing to a file in bash is not very friendly.
for group in $APPENGINE_ADMIN_GROUPS
do
  jq '.metadata.groups += ["'$group'"]' $SERVICE_ACCOUNT_FILE > "credentials.tmp" && mv "credentials.tmp" $SERVICE_ACCOUNT_FILE
done

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
