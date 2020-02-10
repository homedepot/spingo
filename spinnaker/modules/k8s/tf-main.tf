
# Google Provider info
##########################################################

# Get GCP metadata from local gcloud config
##########################################################
data "google_client_config" "gcloud" {
}

# VPCs
##########################################################
resource "google_compute_network" "vpc" {
  for_each                = var.ship_plans_without_agent
  name                    = each.key
  project                 = var.project
  auto_create_subnetworks = "false"
}

# Subnets
##########################################################
resource "google_compute_subnetwork" "subnet" {
  for_each                 = var.ship_plans
  name                     = each.key
  project                  = var.project
  network                  = google_compute_network.vpc[replace(each.key, "-agent", "")].name # https://github.com/terraform-providers/terraform-provider-google/issues/1792
  region                   = each.value["clusterRegion"]
  description              = var.description
  ip_cidr_range            = var.k8s_ip_ranges_map[each.key]["node_cidr"]
  private_ip_google_access = true

  # enable_flow_logs = "${var.enable_flow_logs}" # TODO
  secondary_ip_range {
    range_name    = "${each.key}-k8s-pod"
    ip_cidr_range = var.k8s_ip_ranges_map[each.key]["pod_cidr"]
  }

  secondary_ip_range {
    range_name    = "${each.key}-k8s-svc"
    ip_cidr_range = var.k8s_ip_ranges_map[each.key]["svc_cidr"]
  }
}

# Create a Service Account for the GKE Nodes by default
##########################################################
resource "google_service_account" "sa" {
  for_each     = var.ship_plans
  account_id   = each.key
  display_name = "${each.key} SA"
  project      = var.project
}

resource "google_kms_crypto_key_iam_member" "gke_sa_iam_kms" {
  for_each      = var.ship_plans
  crypto_key_id = var.crypto_key_id_map[each.key]
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@container-engine-robot.iam.gserviceaccount.com"
}

# Create a Service Account key by default
resource "google_service_account_key" "sa_key" {
  for_each           = var.ship_plans
  depends_on         = [google_project_iam_member.iam]
  service_account_id = google_service_account.sa[each.key].name
}

locals {

  deployments = [
    for val in keys(var.ship_plans) : {
      key      = val
      sa_email = google_service_account.sa[val].email
    }
  ]

  roles = [
    for role in var.service_account_iam_roles : {
      key = role
    }
  ]

  deployment_roles = [
    # in a pair, element zero is a deployment and element one is a role,
    # in all unique combinations
    for pair in setproduct(local.deployments, local.roles) : {
      deployment = pair[0].key
      sa_email   = pair[0].sa_email
      role       = pair[1].key
    }
  ]
}

# Add IAM Roles to the Service Account
resource "google_project_iam_member" "iam" {
  for_each = {
    for dr in local.deployment_roles : "${dr.deployment}.${dr.role}" => dr
  }
  member  = "serviceAccount:${each.value.sa_email}"
  project = var.project
  role    = each.value.role
}

