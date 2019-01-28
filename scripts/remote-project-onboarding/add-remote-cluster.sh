#!/bin/bash

set -x

## variables that will change for each target
PROJECT="hd-sqa-nonprod"
REGION="us-central1-a"
CLUSTER="hello-world-cluster"

# hal target name = $PROJECT-$CLUSTER

# 'static' variables that should not change (other than the project substring)
GCP_SERVICE_ACCOUNT_FILE="/spinnaker/accounts/${PROJECT}-spinnaker-gke-admin-account.json" # TODO: fix this
GKE_SERVICE_ACCOUNT_NAME="${PROJECT}-spinnaker-gke-admin-account"
GCP_SERVICE_ACCOUNT_NAME="spinnaker-gke-admin-account"

gcloud auth activate-service-account --key-file="$GCP_SERVICE_ACCOUNT_FILE" --project "$PROJECT"

GCP_SERVICE_ACCOUNT_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:${GCP_SERVICE_ACCOUNT_NAME}" \
    --format='value(email)')

#gcloud config set account "$GCP_SERVICE_ACCOUNT_NAME"

gcloud beta container clusters get-credentials "$CLUSTER" --region "$REGION" --project "$PROJECT" --account "$GCP_SERVICE_ACCOUNT_EMAIL"


kubectl config set-credentials "$GKE_SERVICE_ACCOUNT_NAME" --token=$(kubectl get secret $(kubectl get secret --namespace=kube-system | grep default-token | awk '{print $1}') --namespace=kube-system -o jsonpath={.data.token} | base64 -d)

kubectl config set-context $(kubectl config current-context) --user="$GKE_SERVICE_ACCOUNT_NAME"

### do hal stuff after this


