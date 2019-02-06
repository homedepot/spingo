#!/bin/bash

set -x

## variables that will change for each target
PROJECT="hd-sqa-nonprod"
REGION="us-central1-a"
CLUSTER="hello-world-cluster"

# 'static' variables that should not change (other than the project substring)
GCP_SERVICE_ACCOUNT_FILE="/spinnaker/accounts/${PROJECT}-spinnaker-gke-admin-account.json" # TODO: fix this - e.g. make the path prefix more dynamic, and include project name as part of the path
GKE_SERVICE_ACCOUNT_NAME="${PROJECT}-spinnaker-gke-admin-account"
GCP_SERVICE_ACCOUNT_NAME="spinnaker-gke-admin-account"

gcloud auth activate-service-account --key-file="$GCP_SERVICE_ACCOUNT_FILE" --project "$PROJECT"

GCP_SERVICE_ACCOUNT_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:${GCP_SERVICE_ACCOUNT_NAME}" \
    --format='value(email)')

# have gcloud use the legacy authorization properly (so it doesn't populate the kub config file with all the gcloud crap)
gcloud config set container/use_client_certificate true

gcloud beta container clusters get-credentials "$CLUSTER" --region "$REGION" --project "$PROJECT" --account "$GCP_SERVICE_ACCOUNT_EMAIL"


kubectl config set-credentials "$GKE_SERVICE_ACCOUNT_NAME" --token=$(kubectl get secret $(kubectl get secret --namespace=kube-system | grep default-token | awk '{print $1}') --namespace=kube-system -o jsonpath={.data.token} | base64 -d)


########### do hal stuff after this

hal config provider kubernetes account add hd-sqa-nonprod-hello-world-cluster --context gke_hd-sqa-nonprod_us-central1-a_hello-world-cluster --provider-version v2 --docker-registries docker-registry --only-spinnaker-managed=true

hal config provider kubernetes account add hd-sqa-nonprod-hello-world-cluster-permissions --context gke_hd-sqa-nonprod_us-central1
-a_hello-world-cluster --provider-version v2 --docker-registries docker-registry --write-permissions=gg_pim_sshblk11_np --read-permissions=gg_pim_sshblk11_np --only-spinnaker-managed=true