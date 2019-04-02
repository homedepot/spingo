resource "kubernetes_namespace" "spinnaker" {
  metadata {
    name = "${var.namespace}"
  }
}

resource "kubernetes_secret" "secret" {
  metadata {
    name      = "${var.name}"
    namespace = "${var.namespace}"
  }

  data {
    "secret" = "${base64decode(var.secret-contents)}"
  }

  depends_on = ["kubernetes_namespace.spinnaker"]
}
