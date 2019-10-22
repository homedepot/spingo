terraform {
  backend "gcs" {
  }
}

provider "vault" {
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]

  # credentials = file("terraform-account.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
  region  = var.region
}

resource "google_compute_address" "ui" {
  name   = "spinnaker-ui"
  region = var.region
}

resource "google_compute_address" "api" {
  name   = "spinnaker-api"
  region = var.region
}

resource "google_compute_address" "sandbox-ui" {
  name   = "sandbox-ui"
  region = var.region
}

resource "google_compute_address" "sandbox-api" {
  name   = "sandbox-api"
  region = var.region
}

# The static IP address for Halyard is being provisioned here so that the Halyard VM can be destroyed without loosing the IP which has to be added to k8s master whitelist
resource "google_compute_address" "halyard" {
  name   = "halyard-external-ip"
  region = var.region
}

resource "google_compute_address" "spinnaker-cloudnat" {
  name   = "spinnaker-${var.region}-nat"
  region = var.region
  lifecycle {
    ignore_changes = [users]
  }
}

resource "google_compute_address" "sandbox-cloudnat" {
  name   = "sandbox-${var.region}-nat"
  region = var.region
  lifecycle {
    ignore_changes = [users]
  }
}
