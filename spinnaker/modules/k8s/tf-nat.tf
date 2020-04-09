data "google_compute_address" "existing_nat" {
  for_each = var.ship_plans
  name     = var.cloudnat_name_map[replace(each.key, "-agent", "")]
  region   = each.value["clusterRegion"]
}

# Create a NAT router so the nodes can reach DockerHub, etc
resource "google_compute_router" "router" {
  for_each    = var.ship_plans_without_agent
  name        = each.key
  network     = google_compute_network.vpc[each.key].self_link
  project     = var.project
  region      = each.value["clusterRegion"]
  description = var.description

  bgp {
    asn = var.nat_bgp_asn
  }
}

resource "google_compute_router_nat" "nat" {
  for_each                           = var.ship_plans_without_agent
  name                               = each.key
  project                            = var.project
  router                             = google_compute_router.router[each.key].name
  region                             = each.value["clusterRegion"]
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [data.google_compute_address.existing_nat[each.key].self_link]
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  log_config {
    enable = false
    filter = "ALL"
  }

  subnetwork {
    name                    = google_compute_subnetwork.subnet[each.key].self_link
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE", "LIST_OF_SECONDARY_IP_RANGES"]

    secondary_ip_range_names = [
      "${each.key}-k8s-pod",
      "${each.key}-k8s-svc",
    ]
  }

  subnetwork {
    name                    = google_compute_subnetwork.subnet["${each.key}-agent"].self_link
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE", "LIST_OF_SECONDARY_IP_RANGES"]

    secondary_ip_range_names = [
      "${each.key}-agent-k8s-pod",
      "${each.key}-agent-k8s-svc",
    ]
  }
}


# For old version of NAT Gateway (VM)
# Route traffic to the Masters through the default gateway. This fixes things like kubectl exec and logs
##########################################################
resource "google_compute_route" "gtw_route" {
  for_each         = var.ship_plans_without_agent
  name             = each.key
  dest_range       = google_container_cluster.cluster[each.key].endpoint
  network          = google_compute_network.vpc[each.key].name
  next_hop_gateway = "default-internet-gateway"
  priority         = 700
  project          = var.project
  tags             = [each.key]
}

