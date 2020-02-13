#!/usr/bin/env bash
need "kubectl"

namespace=${namespace}

kubectl create -f https://raw.githubusercontent.com/homedepot/kube-cleanup-operator/master/deploy/rbac.yaml
kubectl create -f https://raw.githubusercontent.com/homedepot/kube-cleanup-operator/master/deploy/deployment.yaml
kubectl logs -f $(kubectl get pods --namespace ${namespace} -l "run=cleanup-operator" -o jsonpath="{.items[0].metadata.name}")


echo "Cleanup Operator created on cluster"