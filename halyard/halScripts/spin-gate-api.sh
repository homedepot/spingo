
%{ for deployment in deployments ~}
echo "Creating Gate x509 API Service for deployment named ${deployment}"
cat <<SVC_EOF | kubectl -n spinnaker --kubeconfig="${KUBE_CONFIG}" apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: spin
    cluster: spin-gate
  name: spin-gate-api
  namespace: spinnaker
spec:
  loadBalancerIP: ${SPIN_API_CLIENT_IP}
  ports:
  - port: 443
    protocol: TCP
    targetPort: 8085
  selector:
    app: spin
    cluster: spin-gate
  sessionAffinity: None
  type: LoadBalancer
SVC_EOF

echo "Added Gate x509 API Service for deployment named ${deployment}"

%{ endfor ~}
