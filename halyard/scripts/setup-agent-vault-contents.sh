
if [ ! -d /${USER}/vault ]; then
  mkdir /${USER}/vault
fi

# had some issues passing this url to the helm install command, so we'll just download the archive manually.
wget -O /tmp/vault-helm-v0.4.0.tar.gz https://github.com/hashicorp/vault-helm/archive/v0.4.0.tar.gz

%{ for deployment, details in deployments ~}

echo "${details.vaultYaml}" | base64 -d > /${USER}/vault/vault_agent_${details.clusterName}_helm_values.yml

echo "Creating vault namespace for deployment ${deployment} in agent cluster"

kubectl --kubeconfig="${details.kubeConfig}" create namespace vault

helm install \
    vault \
    --namespace vault \
    --kubeconfig "${details.kubeConfig}" \
    --values /${USER}/vault/vault_agent_${details.clusterName}_helm_values.yml \
    /tmp/vault-helm-v0.4.0.tar.gz

echo "Waiting for vault to be installed for deployment ${deployment} in agent cluster"
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

echo "Checking to see if vault was setup successfully for deployment ${deployment} in agent cluster"

kubectl -n vault get po -l=app.kubernetes.io/name=vault \
  --kubeconfig="${details.kubeConfig}" \
  -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -v "false"

if [ $? -ne 0 ]; then
    echo "Vault setup for cluster ${deployment} has failed for agent cluster."
    exit 1
fi
echo "Vault is successfully running for cluster ${deployment} in agent cluster"

%{ endfor ~}
