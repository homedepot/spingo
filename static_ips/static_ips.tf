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
  region   = lookup(each.value, "cluster_region", "")
}

resource "google_compute_address" "api" {
  for_each = var.ship_plans
  name     = "api-${each.key}"
  region   = lookup(each.value, "cluster_region", "")
}

resource "google_compute_address" "api_x509" {
  for_each = var.ship_plans
  name     = "api-x509-${each.key}"
  region   = lookup(each.value, "cluster_region", "")
}

resource "google_compute_address" "vault" {
  for_each = var.ship_plans
  name     = "vault-${each.key}"
  region   = lookup(each.value, "cluster_region", "")
}

resource "google_compute_address" "cloudnat" {
  for_each = var.ship_plans
  name     = "nat-${each.key}"
  region   = lookup(each.value, "cluster_region", "")
  lifecycle {
    ignore_changes = [users]
  }
}

# The static IP address for Halyard is being provisioned here so that the Halyard VM can be destroyed without loosing the IP which has to be added to k8s master whitelist
resource "google_compute_address" "halyard" {
  name   = "halyard-external-ip"
  region = var.region
}

resource "local_file" "foo" {
  content = templatefile("./cluster_tf_template.tpl", {
    deployments = var.ship_plans
  })
  filename = "${path.module}/../spinnaker/main_clusters.tf"
}

output "ui_ips" {
  value = { for s in var.ship_plans : s => google_compute_address.ui[s].address }
}

output "api_ips" {
  value = { for s in var.ship_plans : s => google_compute_address.api[s].address }
}

output "api_x509_ips" {
  value = { for s in var.ship_plans : s => google_compute_address.api_x509[s].address }
}

output "vault_ips" {
  value = { for s in var.ship_plans : s => google_compute_address.vault[s].address }
}

output "cloudnat_ips" {
  value = { for s in var.ship_plans : s => google_compute_address.cloudnat[s].address }
}

output "halyard_ip" {
  value = google_compute_address.halyard.address
}

output "ship_plans" {
  value = var.ship_plans
}
