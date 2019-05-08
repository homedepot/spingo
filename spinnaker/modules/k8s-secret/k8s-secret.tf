resource "kubernetes_namespace" "spinnaker" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "secret" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.spinnaker.metadata[0].name
  }

  data = {
    "secret" = base64decode(var.secret-contents)
  }
}

