#!/bin/bash

PROJECT="np-platforms-cd-thd"
SERVICE_ACCOUNT_NAME="terraform-account"
vault read -field "$PROJECT" secret/"$SERVICE_ACCOUNT_NAME" > "$SERVICE_ACCOUNT_NAME".json
cp "$SERVICE_ACCOUNT_NAME".json ./modules/gce/halyard

