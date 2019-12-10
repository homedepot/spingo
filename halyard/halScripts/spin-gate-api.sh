
%{ for deployment, details in deployments ~}
echo "Creating Gate x509 API Service for deployment named ${deployment}"
cat <<SVC_EOF | kubectl -n spinnaker --kubeconfig="${details.kubeConfig}" apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: spin
    cluster: spin-gate
  name: spin-gate-api
  namespace: spinnaker
spec:
  loadBalancerIP: ${details.clientIP}
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
