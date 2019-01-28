#!/bin/bash

PROJECT="hd-sqa-nonprod"

SERVICE_ACCOUNT_NAME="spinnaker-gke-admin-account"
SERVICE_ACCOUNT_FILE="${PROJECT}-spinnaker-gke-admin-account.json"
# need this:
#@hd-sqa-nonprod.iam.gserviceaccount.com

echo "creating $SERVICE_ACCOUNT_NAME service account"
gcloud --project "$PROJECT" iam service-accounts create \
    "$SERVICE_ACCOUNT_NAME" \
    --display-name "$SERVICE_ACCOUNT_NAME"

SA_EMAIL=$(gcloud --project $PROJECT iam service-accounts list \
    --filter="displayName:${SERVICE_ACCOUNT_NAME}" \
    --format='value(email)')

gcloud --project "$PROJECT" --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/container.clusterAdmin'
gcloud --project "$PROJECT" --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/iam.serviceAccountUser'
gcloud --project "$PROJECT" --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/container.admin'
# needed for image access within project GCR
gcloud --project "$PROJECT" --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/storage.objectViewer'

ls -al $SERVICE_ACCOUNT_FILE
echo "generating keys for $SERVICE_ACCOUNT_NAME"
gcloud --project "$PROJECT" iam service-accounts keys create "$SERVICE_ACCOUNT_FILE" \
    --iam-account "$SA_EMAIL"
ls -al $SERVICE_ACCOUNT_FILE

echo "file to give to hal admins is: $SERVICE_ACCOUNT_FILE"