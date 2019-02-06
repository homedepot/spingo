#!/bin/bash

gcloud auth activate-service-account --key-file="/home/${USER}/${USER}.json" --project "${PROJECT}"
gcloud config set container/use_client_certificate true
gcloud beta container clusters get-credentials "${USER}-${REGION}" --region "${REGION}" --project "${PROJECT}"
kubectl config set-credentials "spin_cluster_account" --token=$(kubectl get secret $(kubectl get secret --namespace=kube-system | grep default-token | awk '{print $1}') --namespace=kube-system -o jsonpath={.data.token} | base64 -d)
kubectl config set-context $(kubectl config current-context) --user="spin_cluster_account"


kubectl config set-credentials spin_cluster_account --token=$(kubectl get secret $(kubectl get secret --namespace=kube-system | gre
p default-token | awk '\''{print $1}'\) --namespace=kube-system -o jsonpath={.data.token} | base64 -d)