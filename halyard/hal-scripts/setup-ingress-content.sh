#!/bin/bash

%{ for deployment, details in deployments ~}

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
