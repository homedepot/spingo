# Need to use Beta provider for private_cluster feature
##########################################################

# GKE
##########################################################

locals {
  private_cluster = var.private_cluster ? ["private"] : []
  auth_list       = flatten([var.networks_that_can_access_k8s_api, formatlist("%s/32", var.cloudnat_ips)])
}

data "google_project" "project" {
}

data "google_container_engine_versions" "master" {
  for_each       = { for k, v in var.ship_plans : v["clusterRegion"] => k... }
  location       = each.key
  version_prefix = var.k8s_version_prefix
}

resource "google_container_cluster" "cluster" {
  for_each   = var.ship_plans
  provider   = google-beta
  name       = each.key
  project    = var.project
  location   = each.value["clusterRegion"]
  network    = google_compute_network.vpc[replace(each.key, "-agent", "")].name # https://github.com/terraform-providers/terraform-provider-google/issues/1792
  subnetwork = google_compute_subnetwork.subnet[each.key].self_link
  workload_identity_config {
    identity_namespace = "${data.google_project.project.project_id}.svc.id.goog"
  }
  cluster_ipv4_cidr           = var.k8s_ip_ranges_map[each.key]["pod_cidr"]
  description                 = var.description
  enable_binary_authorization = var.k8s_options["binary_authorization"]
  enable_kubernetes_alpha     = var.extras["kubernetes_alpha"]
  enable_legacy_abac          = var.enable_legacy_kubeconfig
  logging_service             = var.k8s_options["logging_service"]
  #node_version                = var.node_version == "" ? data.google_container_engine_versions.node.latest_node_version : var.node_version
  min_master_version = var.k8s_version == "" ? data.google_container_engine_versions.master[each.value["clusterRegion"]].default_cluster_version : var.k8s_version
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = local.auth_list
      content {
        cidr_block = cidr_blocks.value
      }
    }
  }

  monitoring_service = var.k8s_options["monitoring_service"]

  remove_default_node_pool = var.remove_default_node_pool

  addons_config {
    horizontal_pod_autoscaling {
      disabled = var.k8s_options["enable_hpa"] ? false : true # enabled: y/n
    }

    http_load_balancing {
      disabled = var.k8s_options["enable_http_load_balancing"] ? false : true # enabled: y/n
    }

    kubernetes_dashboard {
      disabled = var.k8s_options["enable_dashboard"] ? false : true # enabled: y/n
    }

    network_policy_config {
      disabled = var.k8s_options["enable_network_policy"] ? false : true # enabled: y/n
    }
  }

  vertical_pod_autoscaling {
    enabled = var.k8s_options["enable_vpa"] ? true : false
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "${each.key}-k8s-pod"
    services_secondary_range_name = "${each.key}-k8s-svc"
  }

  lifecycle {
    ignore_changes = [
      node_pool,
      network,
      subnetwork,
    ]
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.extras["maintenance_start_time"]
    }
  }

  master_auth {
    username = "" # Disable basic auth
    password = "" # Disable basic auth
    dynamic "client_certificate_config" {
      for_each = var.client_certificate_config
      content {
        # TF-UPGRADE-TODO: The automatic upgrade tool can't predict
        # which keys might be set in maps assigned here, so it has
        # produced a comprehensive set here. Consider simplifying
        # this after confirming which keys can be set in practice.

        issue_client_certificate = client_certificate_config.value.issue_client_certificate
      }
    }
  }

  network_policy {
    enabled  = var.k8s_options["enable_network_policy"]
    provider = var.k8s_options["enable_network_policy"] ? "CALICO" : "PROVIDER_UNSPECIFIED"
  }

  node_pool {
    name = "default-pool"
  }

  pod_security_policy_config {
    enabled = var.k8s_options["enable_pod_security_policy"]
  }

  dynamic "private_cluster_config" {
    for_each = local.private_cluster
    content {
      enable_private_nodes   = var.private_cluster
      master_ipv4_cidr_block = var.k8s_ip_ranges_map[each.key]["master_cidr"]
    }
  }

  database_encryption {
    state    = var.crypto_key_id_map[each.key] == "" ? "DECRYPTED" : "ENCRYPTED"
    key_name = var.crypto_key_id_map[each.key]
  }

  timeouts {
    create = var.timeouts["create"]
    update = var.timeouts["update"]
    delete = var.timeouts["delete"]
  }

  depends_on = [
    google_kms_crypto_key_iam_member.gke_sa_iam_kms
  ]
}

resource "google_container_node_pool" "primary_pool" {
  for_each           = var.ship_plans
  provider           = google-beta
  name               = "${each.key}-primary-pool"
  cluster            = google_container_cluster.cluster[each.key].name
  location           = each.value["clusterRegion"]
  project            = var.project
  version            = var.node_version == "" ? data.google_container_engine_versions.master[each.value["clusterRegion"]].default_cluster_version : var.node_version
  initial_node_count = var.node_pool_options_map[each.key]["autoscaling_nodes_min"]

  autoscaling {
    min_node_count = var.node_pool_options_map[each.key]["autoscaling_nodes_min"]
    max_node_count = var.node_pool_options_map[each.key]["autoscaling_nodes_max"]
  }

  management {
    auto_repair  = var.node_pool_options_map[each.key]["auto_repair"]
    auto_upgrade = var.node_pool_options_map[each.key]["auto_upgrade"]
  }

  max_pods_per_node = var.node_pool_options_map[each.key]["max_pods_per_node"]

  node_config {
    disk_size_gb = var.node_options_map[each.key]["disk_size"]
    disk_type    = var.node_options_map[each.key]["disk_type"]

    # Forces new resource due to computing count :/
    # guest_accelerator {
    #   count = "${length(var.node_options_map[each.key]["guest_accelerator"])}"
    #   type = "${var.node_options_map[each.key]["guest_accelerator"]}"
    # }
    image_type = var.node_options_map[each.key]["image"]

    # labels = "${var.node_labels}" # Forces new resource due to computing count :/
    local_ssd_count = var.extras["local_ssd_count"]
    machine_type    = var.node_options_map[each.key]["machine_type"]
    metadata        = var.node_metadata

    # minimum_cpu_platform = "" # TODO
    oauth_scopes    = var.oauth_scopes
    preemptible     = var.node_options_map[each.key]["preemptible"]
    service_account = var.service_account == "" ? google_service_account.sa[each.key].email : var.service_account
    tags            = [replace(each.key, "-agent", "")]

    workload_metadata_config {
      node_metadata = var.extras["metadata_config"]
    }
  }
}
