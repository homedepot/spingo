
if [ ! -d /${USER}/vault ]; then
  mkdir /${USER}/vault
fi

%{ for deployment, details in deployments ~}

echo "${details.vaultYaml}" | base64 -d > /${USER}/vault/vault_${details.clusterName}_helm_values.yml

echo "Creating vault namespace for deployment ${deployment}"

kubectl --kubeconfig="${details.kubeConfig}" create namespace vault

echo "Setting SSL to secret within vault namespace for deployment ${deployment}"

cat <<SECRET_EOF | kubectl -n vault --kubeconfig="${details.kubeConfig}" apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: vault-tls
  namespace: vault
type: Opaque
data:
  vault.pem: $(cat /${USER}/certbot/${DNS}_wildcard.crt | base64 -w 0)
  vault.key: $(cat /${USER}/certbot/${DNS}_wildcard.key | base64 -w 0)
SECRET_EOF

echo "Creating Tiller service account and RBAC for deployment ${deployment}"

cat << TILLER_RBAC | kubectl --kubeconfig="${details.kubeConfig}" create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system

TILLER_RBAC

echo "Initializing Helm for deployment ${deployment}"

helm init \
    --service-account tiller \
    --kubeconfig "${details.kubeConfig}" \
    --history-max 200

echo "Waiting for tiller to be up and ready for deployment ${deployment}"
n=0
until [ $n -ge 10 ]
do
  kubectl -n kube-system get po -l=name=tiller \
  --kubeconfig="${details.kubeConfig}" \
  -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -v "false" && break
   n=$((n+1))
   echo "Tiller is not ready yet for deployment ${deployment} waiting..."
   sleep 6
done

echo "Starting up vault through helm for deployment ${deployment}"

helm install \
    --name vault \
    --namespace vault \
    --kubeconfig "${details.kubeConfig}" \
    --values /${USER}/vault/vault_${details.clusterName}_helm_values.yml \
    https://github.com/hashicorp/vault-helm/archive/v0.3.0.tar.gz

echo "Waiting for vault to be installed for deployment ${deployment}"
n=0
until [ $n -ge 20 ]
do
  kubectl -n vault get po -l=app.kubernetes.io/name=vault \
  --kubeconfig="${details.kubeConfig}" \
  -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -v "false" && break
   n=$((n+1))
   echo "Vault is not yet installed for deployment ${deployment} waiting..."
   sleep 6
done

echo "Checking to see if vault was setup successfully for deployment ${deployment}"

kubectl -n vault get po -l=app.kubernetes.io/name=vault \
  --kubeconfig="${details.kubeConfig}" \
  -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -v "false"

if [ $? -ne 0 ]; then
    echo "Vault setup for cluster ${deployment} has failed."
    exit 1
fi
echo "Vault is successfully running for cluster ${deployment}"

echo "Getting vault root token for deployment ${deployment}"

gsutil cat gs://${details.vaultBucket}/root-token.enc | base64 -d | gcloud kms decrypt \
      --key=${details.vaultKmsKey} \
      --keyring=${details.vaultKmsKeyRingName} \
      --location=${details.clusterRegion} \
      --ciphertext-file='-' \
      --plaintext-file='-' > /home/${USER}/.vault-token

echo "Starting vault kubernetes auth for deployment ${deployment}"

echo "Creating vault-auth kubbernetes service account for deployment ${deployment}"

kubectl -n default \
  create serviceaccount vault-auth \
  --kubeconfig="${details.kubeConfig}"

echo "Creating vault-auth kubbernetes service account for agent cluster of deployment ${deployment}"

kubectl -n default \
  create serviceaccount vault-auth \
  --kubeconfig="/${USER}/.kube/${deployment}-agent.config"

echo "Adding cluster role binding for vault-auth service account for deployment ${deployment}"

cat << VAULT_AUTH_SVC_ACCT | kubectl --kubeconfig="${details.kubeConfig}" -n default apply --filename -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: default

VAULT_AUTH_SVC_ACCT

echo "Adding cluster role binding for vault-auth service account for agent cluster deployment ${deployment}"

cat << VAULT_AUTH_SVC_ACCT | kubectl --kubeconfig="/${USER}/.kube/${deployment}-agent.config" -n default apply --filename -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: default

VAULT_AUTH_SVC_ACCT

echo "Waiting for vault to be up and running for deployment ${deployment}"
n=0
until [ $n -ge 20 ]
do
   vault status \
    -address="https://${details.vaultAddr}" \
    -format=json && break
   n=$((n+1))
   echo "Vault is not yet up and running for deployment ${deployment} waiting..."
   sleep 6
done

echo "Enabling kubernetes auth on vault for deployment ${deployment}"

vault auth enable \
    -address="https://${details.vaultAddr}" \
    --path="kubernetes-${details.clusterName}" \
    kubernetes

echo "Enabling kubernetes auth on vault for agent cluster deployment ${deployment}"

vault auth enable \
    -address="https://${details.vaultAddr}" \
    --path="kubernetes-${details.clusterName}-agent" \
    kubernetes

echo "Creating policy for kubernetes auth for deployment ${deployment}"

cat << VAULT_POLICY | vault policy write -address="https://${details.vaultAddr}" spinnaker-kv-ro -
# For K/V v1 secrets engine
path "secret/spinnaker/*" {
    capabilities = ["read", "list"]
}
# For K/V v2 secrets engine
path "secret/data/spinnaker/*" {
    capabilities = ["read", "list"]
}

VAULT_POLICY

echo "Getting information from kubernetes to complete auth method for deployment ${deployment}"

VAULT_SA_NAME=$(kubectl --kubeconfig="${details.kubeConfig}" -n default get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
SA_JWT_TOKEN=$(kubectl --kubeconfig="${details.kubeConfig}" -n default get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
SA_CA_CRT=$(kubectl --kubeconfig="${details.kubeConfig}" -n default get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
K8S_HOST=$(kubectl --kubeconfig="${details.kubeConfig}" config view -o jsonpath="{.clusters[0].cluster.server}")

echo "Creating kubernetes auth config for deployment ${deployment}"

vault write \
    -address "https://${details.vaultAddr}" \
    auth/kubernetes-${details.clusterName}/config \
    token_reviewer_jwt="$SA_JWT_TOKEN" \
    kubernetes_host="$K8S_HOST" \
    kubernetes_ca_cert="$SA_CA_CRT"

echo "Creating role to map to kubernetes service account"

vault write \
    -address "https://${details.vaultAddr}" \
    auth/kubernetes-${details.clusterName}/role/spinnaker \
    bound_service_account_names="default" \
    bound_service_account_namespaces="*" \
    policies="spinnaker-kv-ro" \
    ttl="1680h"

echo "Getting information from kubernetes to complete auth method for agent cluster deployment ${deployment}"

VAULT_SA_NAME=$(kubectl --kubeconfig="/${USER}/.kube/${deployment}-agent.config" -n default get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
SA_JWT_TOKEN=$(kubectl --kubeconfig="/${USER}/.kube/${deployment}-agent.config" -n default get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
SA_CA_CRT=$(kubectl --kubeconfig="/${USER}/.kube/${deployment}-agent.config" -n default get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
K8S_HOST=$(kubectl --kubeconfig="/${USER}/.kube/${deployment}-agent.config" config view -o jsonpath="{.clusters[0].cluster.server}")

echo "Creating kubernetes auth config for agent cluster deployment ${deployment}"

vault write \
    -address="https://${details.vaultAddr}" \
    auth/kubernetes-${details.clusterName}-agent/config \
    token_reviewer_jwt="$SA_JWT_TOKEN" \
    kubernetes_host="$K8S_HOST" \
    kubernetes_ca_cert="$SA_CA_CRT"

echo "Creating role to map to kubernetes service account for agent cluster deployment ${deployment}"

vault write \
    -address="https://${details.vaultAddr}" \
    auth/kubernetes-${details.clusterName}-agent/role/spinnaker \
    bound_service_account_names="default" \
    bound_service_account_namespaces="*" \
    policies="spinnaker-kv-ro" \
    ttl="1680h"

echo "Ending vault kubernetes auth for deployment ${deployment}"

echo "Starting Vault GCP Auth (GCE) for deployment ${deployment}"

vault auth enable -address="https://${details.vaultAddr}" gcp

vault write \
    -address="https://${details.vaultAddr}" \
    auth/gcp/role/gcp_gce_role \
    project_id="${PROJECT}" \
    type="gce" \
    policies="spinnaker-kv-ro" \
    bound_regions="${details.clusterRegion}"

echo "Ending Vault GCP Auth (GCE) for deployment ${deployment}"

echo "Enabling dynamic account secret keystore for deployment ${deployment}"

vault secrets enable -address="https://${details.vaultAddr}" \
    -version=1 \
    -path="secret" \
    -default-lease-ttl=0 \
    -max-lease-ttl=0 \
    kv

cat << DYN_ACCT_START | vault kv put -address="https://${details.vaultAddr}" secret/dynamic_accounts/spinnaker -
{
    "kubernetes": {
        "accounts": []
    }
}

DYN_ACCT_START


echo "Creating AppRole Auth for deployment ${deployment}"

echo "Creating Dynamic Accounts Policy for deployment ${deployment}"

cat << VAULT_POLICY | vault policy write -address="https://${details.vaultAddr}" dynamic_accounts_ro_policy -
# For K/V v1 secrets engine
path "secret/dynamic_accounts/*" {
    capabilities = ["read", "list"]
}
# For K/V v2 secrets engine
path "secret/data/dynamic_accounts/*" {
    capabilities = ["read", "list"]
}

VAULT_POLICY

cat << VAULT_POLICY | vault policy write -address="https://${details.vaultAddr}" dynamic_accounts_rw_policy -
# For K/V v1 secrets engine
path "secret/dynamic_accounts/*" {
    capabilities = ["read", "list", "create", "update", "delete"]
}
# For K/V v2 secrets engine
path "secret/data/dynamic_accounts/*" {
    capabilities = ["read", "list", "create", "update", "delete"]
}

VAULT_POLICY

echo "Enabling Dynamic Accounts Policy for deployment ${deployment}"

vault auth enable \
    -address="https://${details.vaultAddr}" \
    approle

echo "Creating Dynamic Accounts Read Only Role for deployment ${deployment}"

vault write -address="https://${details.vaultAddr}" \
    auth/approle/role/dynamic_accounts_ro_role \
    token_policies="dynamic_accounts_ro_policy" \
    token_max_ttl="1600h" \
    token_num_uses=0 \
    secret_id_num_uses=0

echo "Creating Dynamic Accounts Read Write Role for deployment ${deployment}"

vault write -address="https://${details.vaultAddr}" \
    auth/approle/role/dynamic_accounts_rw_role \
    token_policies="dynamic_accounts_rw_policy" \
    token_max_ttl="1600h" \
    token_num_uses=0 \
    secret_id_num_uses=0

echo "Getting Dynamic Accounts Read Only Role ID for deployment ${deployment}"

vault read -address="https://${details.vaultAddr}" \
    -format=json auth/approle/role/dynamic_accounts_ro_role/role-id \
    | jq -r '.data.role_id' > /${USER}/vault/dyn_acct_${deployment}_ro_role_id

echo "Getting Dynamic Accounts Read Only Secret ID for deployment ${deployment}"

vault write -address="https://${details.vaultAddr}" \
    -format=json \
    -force \
    auth/approle/role/dynamic_accounts_ro_role/secret-id \
    | jq -r '.data.secret_id' > /${USER}/vault/dyn_acct_${deployment}_ro_secred_id

echo "Getting Dynamic Accounts Read Only Token for deployment ${deployment}"

vault write -address="https://${details.vaultAddr}" \
    -format=json auth/approle/login \
    role_id="$(cat /${USER}/vault/dyn_acct_${deployment}_ro_role_id)" \
    secret_id="$(cat /${USER}/vault/dyn_acct_${deployment}_ro_secred_id)" \
    | jq -r '.auth.client_token' > /${USER}/vault/dyn_acct_${deployment}_ro_token

echo "Getting Dynamic Accounts Read Write Role ID for deployment ${deployment}"

vault read -address="https://${details.vaultAddr}" \
    -format=json auth/approle/role/dynamic_accounts_rw_role/role-id \
    | jq -r '.data.role_id' > /${USER}/vault/dyn_acct_${deployment}_rw_role_id

echo "Getting Dynamic Accounts Read Write Secret ID for deployment ${deployment}"

vault write -address="https://${details.vaultAddr}" \
    -format=json \
    -force \
    auth/approle/role/dynamic_accounts_rw_role/secret-id \
    | jq -r '.data.secret_id' > /${USER}/vault/dyn_acct_${deployment}_rw_secred_id

echo "Getting Dynamic Accounts Read Write Token for deployment ${deployment}"

vault write -address="https://${details.vaultAddr}" \
    -format=json auth/approle/login \
    role_id="$(cat /${USER}/vault/dyn_acct_${deployment}_rw_role_id)" \
    secret_id="$(cat /${USER}/vault/dyn_acct_${deployment}_rw_secred_id)" \
    | jq -r '.auth.client_token' > /${USER}/vault/dyn_acct_${deployment}_rw_token

echo "Getting information from kubernetes to complete auth method spinnaker-onboarding for agent cluster deployment ${deployment}"

VAULT_SA_NAME=$(kubectl --kubeconfig="/${USER}/.kube/${deployment}-agent.config" -n default get sa spinnaker-onboarding -o jsonpath="{.secrets[*]['name']}")
SA_JWT_TOKEN=$(kubectl --kubeconfig="/${USER}/.kube/${deployment}-agent.config" -n default get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
SA_CA_CRT=$(kubectl --kubeconfig="/${USER}/.kube/${deployment}-agent.config" -n default get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
K8S_HOST=$(kubectl --kubeconfig="/${USER}/.kube/${deployment}-agent.config" config view -o jsonpath="{.clusters[0].cluster.server}")

echo "Creating kubernetes auth config spinnaker-onboarding for agent cluster deployment ${deployment}"

vault write \
    -address="https://${details.vaultAddr}" \
    auth/kubernetes-${details.clusterName}-agent/config \
    token_reviewer_jwt="$SA_JWT_TOKEN" \
    kubernetes_host="$K8S_HOST" \
    kubernetes_ca_cert="$SA_CA_CRT"

echo "Creating role to map to kubernetes service account spinnaker-onboarding for agent cluster deployment ${deployment}"

vault write \
    -address="https://${details.vaultAddr}" \
    auth/kubernetes-${details.clusterName}-agent/role/onboarding \
    bound_service_account_names="spinnaker-onboarding" \
    bound_service_account_namespaces="spinnaker" \
    policies="dynamic_accounts_rw_policy" \
    ttl="1680h"

echo "Ending vault kubernetes auth for spinnaker-onboarding deployment ${deployment}"

rm /home/${USER}/.vault-token

%{ endfor ~}
