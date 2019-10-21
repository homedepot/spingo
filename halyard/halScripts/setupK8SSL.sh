
kubectl --kubeconfig="${KUBE_CONFIG}" -n spinnaker patch svc spin-deck --type=merge -p '{"spec": {"ports": [{"name": "http","port": 443,"targetPort": 9000},{"name": "monitoring","port": 8008,"targetPort": 8008}],"type": "LoadBalancer","loadBalancerIP": "'"${SPIN_UI_IP}"'"}}'
kubectl --kubeconfig="${KUBE_CONFIG}" -n spinnaker patch svc spin-gate --type=merge -p '{"spec": {"ports": [{"name": "http","port": 443,"targetPort": 8084},{"name": "monitoring","port": 8008,"targetPort": 8008}],"type": "LoadBalancer","loadBalancerIP": "'"${SPIN_API_IP}"'"}}'
