#!/bin/bash

# PREREQUISITES
# logged-in to gcloud: `gcloud auth login --project np-platforms-cd-thd`
# logged into vault
# `export VAULT_ADDR=https://vault.ioq1.homedepot.com:10231`
# `vault login <some token>`

set +x 

gcloud services enable compute.googleapis.com

PROJECT=np-platforms-cd-thd
SERVICE_ACCOUNT_NAME=terraform-account
SERVICE_ACCOUNT_DEST=terraform-account.json

gcloud iam service-accounts create \
    "$SERVICE_ACCOUNT_NAME" \
    --display-name "$SERVICE_ACCOUNT_NAME"

SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:${SERVICE_ACCOUNT_NAME}" \
    --format='value(email)')

PROJECT=$(gcloud info --format='value(config.project)')

gcloud projects add-iam-policy-binding "$PROJECT" \
    --role roles/storage.admin \
    --member serviceAccount:"$SA_EMAIL"

gcloud projects add-iam-policy-binding "$PROJECT" \
    --role roles/appengine.appAdmin \
    --member serviceAccount:"$SA_EMAIL"

gcloud iam service-accounts keys create "$SERVICE_ACCOUNT_DEST" \
    --iam-account "$SA_EMAIL"

vault write secret/terraform-account value=@terraform-account.json

