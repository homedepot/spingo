terraform {
  backend "gcs" {
    bucket      = "np-platforms-cd-thd-tf"
    prefix      = "np-dns"
    credentials = "terraform-account-dns.json"
  }
}

provider "vault" {
  address = "${var.vault_address}"
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = "${data.vault_generic_secret.terraform-account.data[var.gcp_project]}"

  # credentials = "${file("terraform-account-dns.json")}" //! swtich to this if you need to import stuff from GCP
  project = "${var.gcp_project}"
  region  = "${var.gcp_region}"
}

resource "google_dns_managed_zone" "project_zone" {
  name     = "${var.gcp_project}"
  dns_name = "${var.gcp_project}${var.cloud_dns_hostname}."
}
