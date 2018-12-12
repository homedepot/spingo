provider "kubernetes" {
  host                   = "${var.host}"
  client_certificate     = "${base64decode(var.client_certificate)}"
  client_key             = "${base64decode(var.client_key)}"
  cluster_ca_certificate = "${base64decode(var.cluster_ca_certificate)}"
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "${var.service_account_namespace}"
  }
}

resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = "${var.service_account_name}"
    namespace = "${var.service_account_namespace}"
  }
}

resource "kubernetes_cluster_role_binding" "cluster_role_binding" {
  metadata {
    name = "${var.service_account_name}-cluster-role"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "${var.service_account_name}-service-acc"
    namespace = "${var.service_account_namespace}"
    api_group = ""
  }

  depends_on = ["kubernetes_service_account.service_account"]
}
