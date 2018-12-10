#!/bin/bash

# PREREQUISITES
# logged-in to gcloud: `gcloud auth login --project np-platforms-cd-thd`
# logged into vault
# `export VAULT_ADDR=https://vault.ioq1.homedepot.com:10231`
# `vault login <some token>`

# if you need to delete the service account, read https://cloud.google.com/iam/docs/understanding-service-accounts#deleting_and_recreating_service_accounts

PROJECT=np-platforms-cd-thd
SERVICE_ACCOUNT_NAME=terraform-account
SERVICE_ACCOUNT_DEST=terraform-account.json

SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:${SERVICE_ACCOUNT_NAME}" \
    --format='value(email)')

PROJECT=$(gcloud info --format='value(config.project)')

echo "removing resourcemanager.projectIamAdmin,iam.serviceAccountAdmin,iam.serviceAccountKeyAdmin,compute.admin,container.admin,storage.admin,roles/iam.serviceAccountUser roles from $SERVICE_ACCOUNT_NAME"
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

echo "deleting $SERVICE_ACCOUNT_NAME service account"
gcloud -q iam service-accounts delete "$SERVICE_ACCOUNT_NAME@$PROJECT.iam.gserviceaccount.com"

echo "deleting secret/$SERVICE_ACCOUNT_DEST from vault"
vault delete secret/$SERVICE_ACCOUNT_NAME
