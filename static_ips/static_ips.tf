provider "vault" {
}

data "vault_generic_secret" "terraform_account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = data.vault_generic_secret.terraform_account.data[var.gcp_project]

  # credentials = file("${var.terraform_account}.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
}

resource "google_compute_address" "ui" {
  for_each = var.ship_plans
  name     = "ui-${each.key}"
  region   = each.value["clusterRegion"]
}

resource "google_compute_address" "api" {
  for_each = var.ship_plans
  name     = "api-${each.key}"
  region   = each.value["clusterRegion"]
}

resource "google_compute_address" "api_x509" {
  for_each = var.ship_plans
  name     = "api-x509-${each.key}"
  region   = each.value["clusterRegion"]
}

resource "google_compute_address" "vault" {
  for_each = var.ship_plans
  name     = "vault-${each.key}"
  region   = each.value["clusterRegion"]
}

resource "google_compute_address" "cloudnat" {
  for_each = var.ship_plans
  name     = "nat-${each.key}"
  region   = each.value["clusterRegion"]
  lifecycle {
    ignore_changes = [users]
  }
}

# The static IP address for Halyard is being provisioned here so that the Halyard VM can be destroyed without loosing the IP which has to be added to k8s master whitelist
resource "google_compute_address" "halyard" {
  name   = "halyard-external-ip" # needs to be dashes to satisfy regex within provider
  region = var.region
}

output "ui_ips_map" {
  value = { for k, v in var.ship_plans : k => google_compute_address.ui[k].address }
}

output "api_ips_map" {
  value = { for k, v in var.ship_plans : k => google_compute_address.api[k].address }
}

output "api_x509_ips_map" {
  value = { for k, v in var.ship_plans : k => google_compute_address.api_x509[k].address }
}

output "vault_ips_map" {
  value = { for k, v in var.ship_plans : k => google_compute_address.vault[k].address }
}

output "cloudnat_ips_map" {
  value = { for k, v in var.ship_plans : k => google_compute_address.cloudnat[k].address }
}

output "cloudnat_ips" {
  value = [for k, v in var.ship_plans : google_compute_address.cloudnat[k].address]
}

output "cloudnat_name_map" {
  value = { for k, v in var.ship_plans : k => google_compute_address.cloudnat[k].name }
}

output "halyard_ip" {
  value = google_compute_address.halyard.address
}

output "ship_plans" {
  value = var.ship_plans
}
