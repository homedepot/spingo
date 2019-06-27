#!/bin/bash

# Change this to match the specific onboarding bucket name for your project
ONBOARDING_BUCKET_NAME="np-platforms-cd-thd-spinnaker-onboarding"

# Inspired by: https://stackoverflow.com/questions/42170380/how-to-add-users-to-kubernetes-kubectl
# this script creates a service account (spinnaker-user) on a Kubernetes cluster (tested with AWS EKS 1.9)
# prereqs: a kubectl ver 1.10 installed and proper configuration of the heptio authenticator
# this has been tested on Linux in a Cloud9 environment (for MacOS the syntax may be slightly different)

echo    "########################################################################"
echo    "This script will create a new 'spinnaker' service account with admin"
echo    "permissions and upload the credentials to a bucket for use by spinnaker"
echo -e "########################################################################\n\n"


# Optionally namespace name can be provided as input with options -n|--namespace
# If not, service account will be created in default namespace
NAMESPACE="default"
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "Usage: $0 [-n|--namespace <name>]"
      echo '"default" namespace will be used if no arguments given'
      exit
      ;;
    -n|--namespace)
      test ! -z $2 && NAMESPACE=$2
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Limit the access to namespace level if provided
if [ $NAMESPACE == "default" ]; then
  ROLEBINDING="ClusterRoleBinding"
else
  ROLEBINDING="RoleBinding"
fi

echo "Using the namespace \"$NAMESPACE\""

####################################################
########             Dependencies           ########
####################################################

# ensure that the required commands are present needed to run this script
die() { echo "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "jq"
need "base64"
need "gsutil"
need "kubectl"
need "gcloud"

# make sure that a ~/.kube/config file exists or $KUBECONFIG is set before moving forward
if ! { [ -n "$KUBECONFIG" ] || [ -f ~/.kube/config ]; } ; then
  echo "Error: no ~/.kube/config file is present or \$KUBECONFIG is not set. cannot continue"
  echo "You can run the 'gcloud container clusters get-credentials' command to retrieve the gke credentials"
  exit 1
fi

# base64 operates differently in OSX vs linux
if [[ "$OSTYPE" == "darwin"* ]] && [[ ! -f /usr/local/bin/base64 ]]; then
    BASE64_DECODE="-D"
else
    BASE64_DECODE="-d"
fi


####################################################
########           Create an account        ########
####################################################
# Checking the existence of namespace
kubectl get namespace $NAMESPACE &> /dev/null || die "namespace \"$NAMESPACE\" does not exist"
# Create service account for user spinnaker-user
kubectl create sa spinnaker-user --namespace $NAMESPACE
# Get related secret
secret=$(kubectl get sa spinnaker-user --namespace $NAMESPACE -o json | jq -r '.secrets[].name')
# Get ca.crt from secret
kubectl get secret "$secret" --namespace $NAMESPACE -o json | jq -r '.data["ca.crt"]' | base64 "$BASE64_DECODE" > ca.crt
# Get service account token from secret
user_token=$(kubectl get secret "$secret" --namespace $NAMESPACE -o json | jq -r '.data["token"]' | base64 "$BASE64_DECODE")
# Get information from your kubectl config (current-context, server..)
# get current context
c=$(kubectl config current-context)
# get cluster name of context
name=$(kubectl config get-contexts "$c" | awk '{print $3}' | tail -n 1)
# get endpoint of current context
endpoint=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$name\")].cluster.server}")

# Create the yaml to bind the cluster admin role to spinnaker-user
# cluster-admin role:
# When used in a ClusterRoleBinding, it gives full control over every resource in the cluster and in all namespaces.
# When used in a RoleBinding, it gives full control over every resource in the rolebinding's namespace, including the namespace itself
# Ref: https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles
cat <<EOF >> rbac-config-spinnaker-user.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: $ROLEBINDING
metadata:
  name: spinnaker-user
  namespace: $NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: spinnaker-user
    namespace: $NAMESPACE
EOF

# Apply the policy to spinnaker-user
## nota bene: this command is running against the GKE admin account (defaulting to a reference in ~/.kube/config)
kubectl apply -f rbac-config-spinnaker-user.yaml
if [[ "$?" -eq 0 ]]; then
  rm rbac-config-spinnaker-user.yaml
else
  echo "There was an error applying the $ROLEBINDING"
  rm rbac-config-spinnaker-user.yaml
  exit 1
fi


####################################################
########         Consume the account        ########
####################################################


echo -e "Getting current gcloud project configured\n"
PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
echo -e "Current project is : $PROJECT \n"
echo -e "Getting current roles that have GKE Cluster Admin Access \n"
CLUSTER_ADMIN_GROUPS=$(gcloud projects get-iam-policy "$PROJECT" --flatten="bindings[].members" --format="json" 2>/dev/null | jq -r '.[].bindings.members' - | grep 'group:' | awk -F '[@:]' '{print $2}' | sort -u)
INDENTED_CLUSTER_ADMIN_GROUPS=$(echo "$CLUSTER_ADMIN_GROUPS" | sed 's/^/    - /')
echo -e "Getting current user \n"
CURRENT_USER_ACCOUNT=$(gcloud config list account --format "value(core.account)" 2>/dev/null)
echo -e "Getting cluster information \n"
CLUSTER_ENDPOINT_IP=$(echo "$endpoint" | sed 's/https:\/\///')
CLUSTER_LOCATION=$(gcloud container clusters list --filter="endpoint:$CLUSTER_ENDPOINT_IP" --format="value(location)" 2>/dev/null)
CLUSTER_NAME=$(gcloud container clusters list --filter="endpoint:$CLUSTER_ENDPOINT_IP" --format="value(name)" 2>/dev/null)

CLUSTER_ID="gke_${PROJECT}_${CLUSTER_LOCATION}_${CLUSTER_NAME}"
CONFIG_FILE="$CLUSTER_ID.config"

# Set cluster
kubectl config set-cluster "$CLUSTER_ID" --embed-certs=true --server="$endpoint" --certificate-authority=./ca.crt --kubeconfig="$CONFIG_FILE" && rm ca.crt
# Set user credentials
kubectl config set-credentials "spinnaker-user-$CLUSTER_ID" --token="$user_token" --kubeconfig="$CONFIG_FILE"

# Define the combination of spinnaker-user user with the EKS cluster
kubectl config set-context "$CLUSTER_ID" --cluster="$CLUSTER_ID" --user="spinnaker-user-$CLUSTER_ID" --namespace=$NAMESPACE --kubeconfig="$CONFIG_FILE"
kubectl config use-context "$CLUSTER_ID" --kubeconfig="$CONFIG_FILE"

# Append metadata
echo "spinnaker-metadata:" >> "$CONFIG_FILE"
echo "  project: $PROJECT" >> "$CONFIG_FILE"
echo "  location: $CLUSTER_LOCATION" >> "$CONFIG_FILE"
echo "  name: $CLUSTER_NAME" >> "$CONFIG_FILE"
echo "  requestor: $CURRENT_USER_ACCOUNT" >> "$CONFIG_FILE"
echo "  groups:" >> "$CONFIG_FILE"
echo "$INDENTED_CLUSTER_ADMIN_GROUPS" >> "$CONFIG_FILE"

# Create boto file and set path to ensure reliable gsutil operations if the user already has gsutil configurations
cat <<EOF >> boto
[Boto]
https_validate_certificates = True
[GSUtil]
content_language = en
default_api_version = 2
EOF
export BOTO_CONFIG=boto

ONBOARDING_FULL_DESTINATION="$ONBOARDING_BUCKET_NAME/gke/$PROJECT/"
SERVICE_ACCOUNT_DEST="sa.json"

HAS_GCR_REGISTRY=$(gcloud container images list --format=json 2>&1)
HAS_US_GCR_REGISTRY=$(gcloud container images list --format=json --repository=us.gcr.io/"$PROJECT" 2>&1)

if [[ "$HAS_GCR_REGISTRY" != "[]" ]] || [[ "$HAS_US_GCR_REGISTRY" != "[]" ]]; then

  echo "There is one or more supported Google container registries in this project so creating a service account so Spinnaker can read from the registries"

  SERVICE_ACCOUNT_NAME="spinnaker-gcr"

  echo "creating $SERVICE_ACCOUNT_NAME service account"
  gcloud iam service-accounts create \
      "$SERVICE_ACCOUNT_NAME" \
      --display-name "$SERVICE_ACCOUNT_NAME"

  if [[ "$?" -eq 0 ]]; then
    while [ -z $SA_EMAIL ]; do
      echo "waiting for service account to be fully created..."
      sleep 1
      SA_EMAIL=$(gcloud iam service-accounts list \
          --filter="displayName:${SERVICE_ACCOUNT_NAME}" \
          --format='value(email)')
    done

    if [ "$HAS_GCR_REGISTRY" != "[]" ]; then
      echo "Adding object viewer access to Spinnaker's service account to the default registry gcr.io/$PROJECT"
      gsutil iam ch "serviceAccount:$SA_EMAIL:objectViewer" gs://"artifacts.$PROJECT.appspot.com"
    else
      echo "Unable to find any default gcr regestries within the project"
    fi

    if [ "$HAS_US_GCR_REGISTRY" != "[]" ]; then
      echo "Adding object viewer access to Spinnaker's service account to the US registry gcr.io/$PROJECT"
      gsutil iam ch "serviceAccount:$SA_EMAIL:objectViewer" gs://"us.artifacts.$PROJECT.appspot.com"
    else
      echo "Unable to find any US regional specific regestries within the project"
    fi

    gcloud iam service-accounts keys create "$SERVICE_ACCOUNT_DEST" \
      --iam-account "$SA_EMAIL"
    
    gsutil cp "$SERVICE_ACCOUNT_DEST" gs://"$ONBOARDING_FULL_DESTINATION""$SERVICE_ACCOUNT_DEST" && rm "$SERVICE_ACCOUNT_DEST"
  else
    echo "Unable to create service account for the google container registries within project: $PROJECT "
  fi
fi

gsutil cp "$CONFIG_FILE" gs://"$ONBOARDING_FULL_DESTINATION""$CONFIG_FILE" && rm "$CONFIG_FILE"

# Cleanup boto config
rm -f boto
unset BOTO_CONFIG

echo -e "\n\nThe creation of the service account is complete. Please alert the Spinnaker Admin team that you have completed on-boarding so they can finalize the on-boarding process."
