
%{ for deployment, details in deployments ~}

echo "${details.vaultYaml}" | base64 -d > vault_${details.clusterName}.yml

kubectl --kubeconfig="${details.kubeConfig}" create namespace vault

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

kubectl --kubeconfig="${details.kubeConfig}" apply -f vault_${details.clusterName}.yml

n=0
until [ $n -ge 10 ]
do
  kubectl -n vault get po -l=app=vault \
  --kubeconfig="${details.kubeConfig}" \
  -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -v "false" && break
   n=$[$n+1]
   sleep 6
done

kubectl -n vault get po -l=app=vault \
  --kubeconfig="${details.kubeConfig}" \
  -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -v "false"

if [ $? -ne 0 ]; then
    echo "Vault setup for cluster ${deployment} has failed."
    exit 1
fi
echo "Vault is successfully running for cluster ${deployment}"

gsutil cat gs://${details.vaultBucket}/root-token.enc | gcloud kms decrypt \
      --key= \
      --keyring= \
      --location= \
      --ciphertext-file='-' \
      --plaintext-file='-' | vault login -

%{ endfor ~}
