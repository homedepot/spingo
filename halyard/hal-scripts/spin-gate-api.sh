
%{ for deployment, details in deployments ~}
echo "Creating Gate x509 API Service for deployment named ${deployment}"
cat <<SVC_EOF | kubectl --kubeconfig="${details.kubeConfig}" apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: spin
    cluster: spin-gate
  name: spin-gate-spin-api
  namespace: spinnaker
spec:
  loadBalancerIP: ${details.gateSpinApiIP}
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

echo "Creating Gate API Service for deployment named ${deployment}"
cat <<SVC_EOF | kubectl --kubeconfig="${details.kubeConfig}" apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: spin
    cluster: spin-gate
  name: spin-gate-api
  namespace: spinnaker
spec:
  loadBalancerIP: ${details.gateApiIP}
  ports:
  - port: 443
    protocol: TCP
    targetPort: 8084
  selector:
    app: spin
    cluster: spin-gate
  sessionAffinity: None
  type: LoadBalancer
SVC_EOF

echo "Added Gate API Service for deployment named ${deployment}"

echo "Creating Deck UI Service for deployment named ${deployment}"
cat <<SVC_EOF | kubectl --kubeconfig="${details.kubeConfig}" apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: spin
    cluster: spin-deck
  name: spin-deck-ui
  namespace: spinnaker
spec:
  loadBalancerIP: ${details.uiIP}
  ports:
  - port: 443
    protocol: TCP
    targetPort: 9000
  selector:
    app: spin
    cluster: spin-deck
  sessionAffinity: None
  type: LoadBalancer
SVC_EOF

echo "Added Deck UI Service for deployment named ${deployment}"

%{ endfor ~}
