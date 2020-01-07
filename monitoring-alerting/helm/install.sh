#!/bin/bash

if [[ -z "$GF_SERVER_ROOT_URL" ]]; then
    echo GF_SERVER_ROOT_URL must be set. Exiting.
    exit 1
fi
if [[ -z "$GF_AUTH_GOOGLE_CLIENT_ID" ]]; then
    echo GF_AUTH_GOOGLE_CLIENT_ID must be set. Exiting.
    exit 1
fi
if [[ -z "$GF_AUTH_GOOGLE_CLIENT_SECRET" ]]; then
    echo GF_AUTH_GOOGLE_CLIENT_SECRET must be set. Exiting.
    exit 1
fi

# Copy the values file to a temp location to operate with secrets for now.
cp values.yaml /tmp/values.yaml

echo "Editing values.yaml file..."

yq w -i /tmp/values.yaml grafana["grafana.ini"].server.root_url "$GF_SERVER_ROOT_URL"
yq w -i /tmp/values.yaml grafana["grafana.ini"].["auth.google"].client_id "$GF_AUTH_GOOGLE_CLIENT_ID"
yq w -i /tmp/values.yaml grafana["grafana.ini"].["auth.google"].client_secret "$GF_AUTH_GOOGLE_CLIENT_SECRET"

helm install spin stable/prometheus-operator -f /tmp/values.yaml -n monitoring
