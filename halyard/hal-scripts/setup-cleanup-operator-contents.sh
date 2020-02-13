
%{ for deployment, details in deployments ~}



kubectl --kubeconfig="${details.kubeConfig}" create -f https://raw.githubusercontent.com/homedepot/kube-cleanup-operator/master/deploy/rbac.yaml
kubectl --kubeconfig="${details.kubeConfig}" create -f https://raw.githubusercontent.com/homedepot/kube-cleanup-operator/master/deploy/deployment.yaml
kubectl --kubeconfig="${details.kubeConfig}" logs -f $(kubectl get pods --namespace spinnaker -l "run=cleanup-operator" -o jsonpath="{.items[0].metadata.name}")


echo "Cleanup Operator created on cluster"

%{ endfor ~}
