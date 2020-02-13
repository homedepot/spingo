#!/bin/bash
if [ ! -d /${USER}/ingress ]; then
  mkdir /${USER}/ingress
fi

%{ for deployment, details in deployments ~}

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


cat <<SECRET_EOF | kubectl --kubeconfig="${details.kubeConfig}" apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: wildcard-cert
  namespace: kube-system
type: kubernetes.io/tls
data:
  vault.pem: $(cat /${USER}/certbot/${DNS}_wildcard.crt | base64 -w 0)
  vault.key: $(cat /${USER}/certbot/${DNS}_wildcard.key | base64 -w 0)
SECRET_EOF


cat <<EOF > /${USER}/ingress/ingress_${details.clusterName}_nginx-ingress.yml
controller:
  service:
    loadBalancerIP: ${load_balancer_ip}
  extraArgs:
    default-ssl-certificate "kube-system/wildcard-cert"
    enable-ssl-passthrough: {}
EOF

helm install \
	--name nginx-ingress \
	--namespace kube-system \
	--kubeconfig "${details.kubeConfig}" \
	--values /${USER}/ingress/ingress_${details.clusterName}_nginx-ingress.yml \
	stable/nginx-ingress
%{ endfor ~}
