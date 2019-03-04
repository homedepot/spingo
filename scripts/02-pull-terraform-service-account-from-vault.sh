#!/bin/bash

# can also run "gcloud config list --format 'value(core.project)' 2>/dev/null" to get the project name dynamically
PROJECT="np-platforms-cd-thd"
SERVICE_ACCOUNT_NAME="terraform-account"
vault read -field "$PROJECT" secret/"$SERVICE_ACCOUNT_NAME" > "$SERVICE_ACCOUNT_NAME".json
cp "$SERVICE_ACCOUNT_NAME".json ./modules/gce/halyard

