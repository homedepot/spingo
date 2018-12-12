############################################
resource "google_container_cluster" "cluster" {
  name               = "${var.cluster_name}-${var.cluster_region}"
  region             = "${var.cluster_region}"
  min_master_version = "${var.gke_version}"
  node_version       = "${var.gke_version}"
  logging_service    = "${var.logging_service}"
  monitoring_service = "${var.monitoring_service}"
  provider           = "google-beta"

  # Required for now, see:
  # https://github.com/mcuadros/terraform-provider-helm/issues/56
  # https://github.com/terraform-providers/terraform-provider-kubernetes/pull/73
  enable_legacy_abac = "${var.enable_legacy_abac}"

  # Remove the default node pool during cluster creation.
  # We use google_container_node_pools for better control and
  # less disruptive changes.
  # https://github.com/terraform-providers/terraform-provider-google/issues/1712#issuecomment-410317055
  remove_default_node_pool = true

  node_pool {
    name = "default-pool"
  }

  lifecycle {
    ignore_changes = ["node_pool"]
    ignore_changes = ["network"]
  }
}

# Primary node pool
resource "google_container_node_pool" "primary_pool" {
  name               = "${var.cluster_name}-${var.cluster_region}-primary-pool"
  cluster            = "${google_container_cluster.cluster.name}"
  region             = "${var.cluster_region}"
  version            = "${var.gke_version}"
  initial_node_count = 1
  provider           = "google-beta"

  autoscaling {
    min_node_count = "${var.min_node_count}"
    max_node_count = "${var.max_node_count}"
  }

  node_config {
    machine_type = "${var.machine_type}"
    oauth_scopes = ["${var.oauth_scopes}"]
  }
}

output "host" {
  value     = "${google_container_cluster.cluster.endpoint}"
  sensitive = false
}

output "client_certificate" {
  value = "${google_container_cluster.cluster.master_auth.0.client_certificate}"
}

output "client_key" {
  value = "${google_container_cluster.cluster.master_auth.0.client_key}"
}

output "cluster_ca_certificate" {
  value = "${google_container_cluster.cluster.master_auth.0.cluster_ca_certificate}"
}
