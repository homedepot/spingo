provider "kubernetes" {
  host                   = "${var.host}"
  client_certificate     = "${base64decode(var.client_certificate)}"
  client_key             = "${base64decode(var.client_key)}"
  cluster_ca_certificate = "${base64decode(var.cluster_ca_certificate)}"
}

resource "kubernetes_namespace" "spinnaker" {
  metadata {
    name = "spinnaker"
  }
}

resource "kubernetes_service_account" "spinnaker" {
  metadata {
    name = "spinnaker-service-acc"
    namespace = "spinnaker"
  }
}

resource "kubernetes_cluster_role_binding" "spinnaker" {
  metadata {
    name = "spinnaker-cluster-role"
  }

  role_ref {
    kind = "ClusterRole"
    name = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind = "ServiceAccount"
    name = "spinnaker-service-acc"
    namespace = "spinnaker"
    api_group = ""
  }

  depends_on = ["kubernetes_service_account.spinnaker"]
}