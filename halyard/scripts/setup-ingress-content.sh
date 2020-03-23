#!/bin/bash
if [ ! -d /${USER}/ingress ]; then
  mkdir /${USER}/ingress
fi

%{ for deployment, details in deployments ~}

cat <<SECRET_EOF | kubectl --kubeconfig="${details.kubeConfig}" apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: wildcard-cert
  namespace: kube-system
type: kubernetes.io/tls
data:
  tls.crt: $(cat /${USER}/certbot/${DNS}_wildcard.crt | base64 -w 0)
  tls.key: $(cat /${USER}/certbot/${DNS}_wildcard.key | base64 -w 0)
SECRET_EOF


cat <<EOF > /${USER}/ingress/ingress_${details.clusterName}_nginx-ingress.yml
controller:
  service:
    loadBalancerIP: ${details.loadBalancerIP}
  replicaCount: 3
  extraArgs:
    default-ssl-certificate: "kube-system/wildcard-cert"
    enable-ssl-passthrough: {}
EOF

helm install \
	nginx-ingress \
	--namespace kube-system \
	--kubeconfig "${details.kubeConfig}" \
	--values /${USER}/ingress/ingress_${details.clusterName}_nginx-ingress.yml \
	stable/nginx-ingress
%{ endfor ~}
