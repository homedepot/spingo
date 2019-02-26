#!/bin/bash 

# Inspired by: https://stackoverflow.com/questions/42170380/how-to-add-users-to-kubernetes-kubectl
# this script creates a service account (spinnaker-user) on a Kubernetes cluster (tested with AWS EKS 1.9)
# prereqs: a kubectl ver 1.10 installed and proper configuration of the heptio authenticator
# this has been tested on Linux in a Cloud9 environment (for MacOS the syntax may be slightly different)

####################################################
########           Create an account        ######## 
####################################################
# Create service account for user spinnaker-user
kubectl create sa spinnaker-user
# Get related secret
secret=$(kubectl get sa spinnaker-user -o json | jq -r '.secrets[].name')
# Get ca.crt from secret 
kubectl get secret $secret -o json | jq -r '.data["ca.crt"]' | base64 -d > ca.crt
# Get service account token from secret
user_token=$(kubectl get secret $secret -o json | jq -r '.data["token"]' | base64 -d)
# Get information from your kubectl config (current-context, server..)
# get current context
c=`kubectl config current-context`
# get cluster name of context
name=`kubectl config get-contexts $c | awk '{print $3}' | tail -n 1`
# get endpoint of current context 
endpoint=`kubectl config view -o jsonpath="{.clusters[?(@.name == \"$name\")].cluster.server}"`

# Create the yaml to bind the cluster admin role to spinnaker-user
cat <<EOF >> rbac-config-spinnaker-user.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spinnaker-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: spinnaker-user
    namespace: default
EOF

# Apply the policy to spinnaker-user
## nota bene: this command is running against the GKE admin account (defaulting to a reference in ~/.kube/config)
kubectl apply -f rbac-config-spinnaker-user.yaml && rm rbac-config-spinnaker-user.yaml


####################################################
########          Consume the account       ######## 
####################################################

# Set cluster 
kubectl config set-cluster $c --embed-certs=true --server=$endpoint --certificate-authority=./ca.crt --kubeconfig="${c}.config" && rm ca.crt
# Set user credentials 
kubectl config set-credentials "spinnaker-user-${c}" --token=$user_token --kubeconfig="${c}.config"

# Define the combination of spinnaker-user user with the EKS cluster
kubectl config set-context "${c}" --cluster="$c" --user="spinnaker-user-${c}" --namespace=default --kubeconfig="${c}.config"
kubectl config use-context "${c}" --kubeconfig="${c}.config"

gsutil cp "${c}.config" gs://np-platforms-cd-thd-spinnaker-onboarding && rm "${c}.config"

echo -e "\nThe creation of the service account is complete"