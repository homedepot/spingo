#!/bin/bash

gcloud auth activate-service-account --key-file="/home/${USER}/${USER}.json" --project "${PROJECT}"
gcloud beta container clusters get-credentials "${USER}-${REGION}" --region "${REGION}" --project "${PROJECT}"
kubectl config set-credentials "${SPIN_CLUSTER_ACCOUNT}" --token=$(kubectl get secret $(kubectl get secret --namespace=kube-system | grep default-token | awk '{print $1}') --namespace=kube-system -o jsonpath={.data.token} | base64 -d)
kubectl config set-context $(kubectl config current-context) --user="${SPIN_CLUSTER_ACCOUNT}"
