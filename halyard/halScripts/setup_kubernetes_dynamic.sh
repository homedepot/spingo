if [ ! -d /${USER}/.kube ]; then
  mkdir /${USER}/.kube
fi

# ensure that the required commands are present needed to run this script
die() { echo "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

####################################################
########             Dependencies           ########
####################################################

need "jq"
need "base64"
need "kubectl"
need "gcloud"

%{ for deployment, details in deployments ~}

gcloud container clusters get-credentials ${deployment} --region ${details.clusterRegion} --project ${PROJECT}

NAMESPACE="default"
ROLEBINDING="ClusterRoleBinding"

echo "Using the namespace \"$NAMESPACE\""

# make sure that a ~/.kube/config file exists or $KUBECONFIG is set before moving forward
if ! { [ -n "$KUBECONFIG" ] || [ -f ~/.kube/config ]; } ; then
  echo "Error: no ~/.kube/config file is present or \$KUBECONFIG is not set. cannot continue"
  echo "You can run the 'gcloud container clusters get-credentials' command to retrieve the gke credentials"
  exit 1
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
cat <<EOF | kubectl apply -f -
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

####################################################
########         Consume the account        ########
####################################################

echo -e "Getting current gcloud project configured\n"
PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
echo -e "Current project is : $PROJECT \n"
echo -e "Getting cluster information \n"
CLUSTER_ENDPOINT_IP=$(echo "$endpoint" | sed 's/https:\/\///')
CLUSTER_LOCATION=$(gcloud container clusters list --filter="endpoint:$CLUSTER_ENDPOINT_IP" --format="value(location)" 2>/dev/null)
CLUSTER_NAME=$(gcloud container clusters list --filter="endpoint:$CLUSTER_ENDPOINT_IP" --format="value(name)" 2>/dev/null)

CLUSTER_ID="gke_""$PROJECT""_""$CLUSTER_LOCATION""_""$CLUSTER_NAME""_""$NAMESPACE"
CONFIG_FILE="/${USER}/.kube/${deployment}.config"

# Set cluster
kubectl config set-cluster "$CLUSTER_ID" --embed-certs=true --server="$endpoint" --certificate-authority=./ca.crt --kubeconfig="$CONFIG_FILE" && rm ca.crt
# Set user credentials
kubectl config set-credentials "spinnaker-user" --token="$user_token" --kubeconfig="$CONFIG_FILE"

# Define the combination of spinnaker-user user with the EKS cluster
kubectl config set-context "$CLUSTER_ID" --cluster="$CLUSTER_ID" --user="spinnaker-user" --namespace=$NAMESPACE --kubeconfig="$CONFIG_FILE"
kubectl config use-context "$CLUSTER_ID" --kubeconfig="$CONFIG_FILE"

# Append metadata
echo "spinnaker-metadata:" >> "$CONFIG_FILE"
echo "  project: $PROJECT" >> "$CONFIG_FILE"
echo "  location: $CLUSTER_LOCATION" >> "$CONFIG_FILE"
echo "  name: $CLUSTER_NAME" >> "$CONFIG_FILE"
echo "$INDENTED_CLUSTER_ADMIN_GROUPS" >> "$CONFIG_FILE"

%{ endfor ~}