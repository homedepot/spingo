provider "kubernetes" {
  load_config_file       = false
  host                   = "${var.host}"
  cluster_ca_certificate = "${base64decode(var.cluster_ca_certificate)}"
  token                  = "${var.token}"
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
    name      = "${var.service_account_name}"
    namespace = "${var.service_account_namespace}"
    api_group = ""
  }

  depends_on = ["kubernetes_service_account.service_account"]
}

data "kubernetes_secret" "service_account_data" {
  metadata {
    name      = "${kubernetes_service_account.service_account.default_secret_name}"
    namespace = "${kubernetes_service_account.service_account.metadata.0.namespace}"
  }
}

data "template_file" "kubeconfig" {
  template = "${file("${path.module}/kubeconfig.template")}"

  vars {
    CA_CERT = "${var.cluster_ca_certificate}"
    HOST    = "https://${var.host}"
    NAME    = "gke_${var.gcp_project}_${var.cluster_name}_${var.cluster_region}"
    TOKEN   = "${lookup(data.kubernetes_secret.service_account_data.data, "token", "")}"
  }
}

resource "google_storage_bucket_object" "spinnaker_kubeconfig_file" {
  name         = ".kube/config"
  content      = "${data.template_file.kubeconfig.rendered}"
  bucket       = "${var.bucket_name}"
  content_type = "application/text"
}
