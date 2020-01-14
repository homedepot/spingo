provider "vault" {
}

data "vault_generic_secret" "terraform_account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = var.use_local_credential_file ? file("${var.terraform_account}-dns.json") : data.vault_generic_secret.terraform_account.data[var.gcp_project]
  project     = var.gcp_project
}

resource "google_dns_managed_zone" "project_zone" {
  name        = "spinnaker-wildcard-domain"
  description = "Managed by Terraform created by Spingo"
  dns_name    = "${var.cloud_dns_hostname}."
  lifecycle {
    ignore_changes = [
      dnssec_config
    ]
  }
}

output "google_dns_managed_zone_hostname" {
  value = var.cloud_dns_hostname
}

output "google_dns_managed_zone_nameservers" {
  value = google_dns_managed_zone.project_zone.name_servers
}
