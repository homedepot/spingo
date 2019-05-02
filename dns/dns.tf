terraform {
  backend "gcs" {}
}

provider "vault" {}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = "${data.vault_generic_secret.terraform-account.data[var.gcp_project]}"

  # credentials = "${file("terraform-account-dns.json")}" //! swtich to this if you need to import stuff from GCP
  project = "${var.gcp_project}"
}

resource "google_dns_managed_zone" "project_zone" {
  name     = "spinnaker-wildcard-domain"
  dns_name = "${var.cloud_dns_hostname}."
}
