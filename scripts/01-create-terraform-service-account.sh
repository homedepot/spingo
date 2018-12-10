#!/bin/bash

# PREREQUISITES
# logged-in to gcloud: `gcloud auth login --project np-platforms-cd-thd`
# logged into vault
# `export VAULT_ADDR=https://vault.ioq1.homedepot.com:10231`
# `vault login <some token>`

# if you need to delete the service account, see 00-delete-terraform-account.sh

echo "enabling compute.googleapis.com service"
gcloud services enable compute.googleapis.com
echo "enabling iam.googleapis.com service"
gcloud services enable iam.googleapis.com

PROJECT=np-platforms-cd-thd
SERVICE_ACCOUNT_NAME=terraform-account
SERVICE_ACCOUNT_DEST=terraform-account.json

echo "creating $SERVICE_ACCOUNT_NAME service account"
gcloud iam service-accounts create \
    "$SERVICE_ACCOUNT_NAME" \
    --display-name "$SERVICE_ACCOUNT_NAME"

SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:${SERVICE_ACCOUNT_NAME}" \
    --format='value(email)')

PROJECT=$(gcloud info --format='value(config.project)')

echo "adding resourcemanager.projectIamAdmin,iam.serviceAccountAdmin,iam.serviceAccountKeyAdmin,compute.admin,container.admin,storage.admin roles to $SERVICE_ACCOUNT_NAME"
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/resourcemanager.projectIamAdmin'
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role='roles/iam.serviceAccountAdmin'
gcloud --no-user-output-enabled projects add-iam-policy-binding "$PROJECT" \
    --member serviceAccount:"$SA_EMAIL" \
    --role 'roles/iam.serviceAccountKeyAdmin'
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

echo "generating keys for $SERVICE_ACCOUNT_NAME"
gcloud iam service-accounts keys create "$SERVICE_ACCOUNT_DEST" \
    --iam-account "$SA_EMAIL"

echo "writing $SERVICE_ACCOUNT_DEST to vault in secret/terraform-account & deleting temp file"
vault write secret/terraform-account "$PROJECT"=@${SERVICE_ACCOUNT_DEST} && rm "$SERVICE_ACCOUNT_DEST"
