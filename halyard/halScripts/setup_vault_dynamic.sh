
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

%{ endfor ~}
