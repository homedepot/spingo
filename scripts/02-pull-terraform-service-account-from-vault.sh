#!/bin/bash

# can also run "gcloud config list --format 'value(core.project)' 2>/dev/null" to get the project name dynamically
PROJECT="np-platforms-cd-thd"
DNS_PROJECT="np-platforms-cd-thd"
SERVICE_ACCOUNT_NAME="terraform-account"
DNS_SERVICE_ACCOUNT_NAME="terraform-account-dns"

vault read -field "$PROJECT" secret/"$PROJECT"/"$SERVICE_ACCOUNT_NAME" > "$SERVICE_ACCOUNT_NAME".json
vault read -field "$DNS_PROJECT" secret/"$DNS_PROJECT"/"$SERVICE_ACCOUNT_NAME" > "$DNS_SERVICE_ACCOUNT_NAME".json
cp "$SERVICE_ACCOUNT_NAME".json ./halyard
cp "$DNS_SERVICE_ACCOUNT_NAME".json ./dns
