# # This service account uses the ClusterAdmin role -- this is not necessary, 
# # more restrictive roles can by applied.
# kubectl apply --context $CONTEXT \
#     -f https://spinnaker.io/downloads/kubernetes/service-account.yml

# TOKEN=$(kubectl get secret --context $CONTEXT \
#    $(kubectl get serviceaccount spinnaker-service-account \
#        --context $CONTEXT \
#        -n spinnaker \
#        -o jsonpath='{.secrets[0].name}') \
#    -n spinnaker \
#    -o jsonpath='{.data.token}' | base64 --decode)

# kubectl config set-credentials ${CONTEXT}-token-user --token $TOKEN

# kubectl config set-context $CONTEXT --user ${CONTEXT}-token-user


provider "kubernetes" {
  host                   = "${var.host}"
  client_certificate     = "${base64decode(var.client_certificate)}"
  client_key             = "${base64decode(var.client_key)}"
  cluster_ca_certificate = "${base64decode(var.cluster_ca_certificate)}"
#   username = "${var.username}"
#   password = "${var.password}"
}

resource "kubernetes_namespace" "spinnaker" {
  metadata {
    name = "spinnaker"
  }
}

# resource "kubernetes_namespace" "spinnaker2" {
#   metadata {
#     name = "spinnaker2"
#   }
# }


# resource "kubernetes_service_account" "spinnaker" {
#   metadata {
#     name = "spinnaker-service-acc"
#     namespace = "spinnaker"
#   }
# }

# resource "kubernetes_cluster_role_binding" "spinnaker" {
#   metadata {
#     name = "spinnaker-cluster-role"
#   }

#   role_ref {
#     kind = "ClusterRole"
#     name = "cluster-admin"
#     api_group = "rbac.authorization.k8s.io"
#   }

#   subject {
#     kind = "ServiceAccount"
#     name = "spinnaker-service-acc"
#     namespace = "spinnaker"
#     api_group = ""
#   }

#   provisioner "local-exec" {
#     command = "./files/scripts/spinnaker.sh"
#   }

#   depends_on = ["kubernetes_service_account.spinnaker"]
# }