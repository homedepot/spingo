provider "vault" {
  address = "${var.vault_address}"
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.terraform_account}"
}

provider "google" {
  credentials = "${data.vault_generic_secret.terraform-account.data[var.gcp_project]}"
  project     = "${var.gcp_project}"
  region      = "${var.gcp_region}"
}

data "google_project" "project" {}

module "spin-k8s-cluster" {
  source                   = "./modules/spin-k8s-cluster"
  cluster_name             = "spinnaker"
  cluster_regions          = ["us-east1"]
  enable_legacy_abac       = true
  master_authorized_network_cidrs = []
}

module "halyard-storage" {
  source                   = "./modules/halyard-storage"
  gcp_project              = "${var.gcp_project}"
}
