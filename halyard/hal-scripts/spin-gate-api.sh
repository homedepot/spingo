
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
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  labels:
    app: spin
    cluster: spin-gate
  name: spin-gate-api
  namespace: spinnaker
spec:
  rules:
  - host: ${details.gateApiHostname}
    http:
      paths:
      - backend:
          serviceName: spin-gate
          servicePort: 8084
        path: /
SVC_EOF

echo "Added Gate API Service for deployment named ${deployment}"

echo "Creating Deck UI Service for deployment named ${deployment}"
cat <<SVC_EOF | kubectl --kubeconfig="${details.kubeConfig}" apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  labels:
    app: spin
    cluster: spin-deck
  name: spin-deck-ui
  namespace: spinnaker
spec:
  rules:
  - host: ${details.deckHostname}
    http:
      paths:
      - backend:
          serviceName: spin-deck
          servicePort: 9000
        path: /
  tls:
  - hosts:
    - sandbox.spinnaker.homedepot.com
SVC_EOF

echo "Added Deck UI Service for deployment named ${deployment}"

%{ endfor ~}
