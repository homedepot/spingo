resource "kubernetes_secret" "secret" {
  metadata {
    name      = "${var.name}"
    namespace = "${var.namespace}"
  }

  data {
    "secret" = "${base64decode(var.secret-contents)}"
  }
}
