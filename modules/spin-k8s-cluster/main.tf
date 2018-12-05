############################################
resource "google_container_cluster" "cluster" {
  count              = "${length(var.cluster_regions)}"
  name               = "${var.cluster_name}-${var.cluster_regions[count.index]}-${count.index}"
  region             = "${var.cluster_regions[count.index]}"
  min_master_version = "${var.gke_version}"
  node_version       = "${var.gke_version}"
  logging_service    = "${var.logging_service}"
  monitoring_service = "${var.monitoring_service}"

  # Required for now, see:
  # https://github.com/mcuadros/terraform-provider-helm/issues/56
  # https://github.com/terraform-providers/terraform-provider-kubernetes/pull/73
  enable_legacy_abac = "${var.enable_legacy_abac}"

  # master_authorized_networks_config {
  #   cidr_blocks = ["${var.master_authorized_network_cidrs}"]
  # }

  # Remove the default node pool during cluster creation.
  # We use google_container_node_pools for better control and
  # less disruptive changes.
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
  count              = "${length(var.cluster_regions)}"
  name               = "${var.cluster_name}-${var.cluster_regions[count.index]}-${count.index}-primary-pool"
  cluster            = "${google_container_cluster.cluster.*.name[count.index]}"
  region             = "${var.cluster_regions[count.index]}"
  version            = "${var.gke_version}"
  initial_node_count = 1

  autoscaling {
    min_node_count = "${var.min_node_count}"
    max_node_count = "${var.max_node_count}"
  }

  node_config {
    machine_type = "${var.machine_type}"
    oauth_scopes = ["${var.oauth_scopes}"]
  }
}

output "endpoints" {
  value = "${google_container_cluster.cluster.*.endpoint}"
}

output "master_auths" {
  value = "${google_container_cluster.cluster.*.master_auth}"
}