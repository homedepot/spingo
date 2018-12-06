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
provider "google-beta" {
  credentials = "${data.vault_generic_secret.terraform-account.data[var.gcp_project]}"
  project     = "${var.gcp_project}"
  region      = "${var.gcp_region}"
}

data "google_project" "project" {}

module "spin-k8s-cluster" {
  source                          = "./modules/spin-k8s-cluster"
  cluster_name                    = "spinnaker"
  cluster_region                  = "us-east1"
  enable_legacy_abac              = true
  master_authorized_network_cidrs = []
}

module "halyard-storage" {
  source      = "./modules/halyard-storage"
  gcp_project = "${var.gcp_project}"
}

module "service-accounts" {
  source                 = "./modules/service-accounts"
  host                   = "${module.spin-k8s-cluster.host}"
  client_certificate     = "${module.spin-k8s-cluster.client_certificate}"
  client_key             = "${module.spin-k8s-cluster.client_key}"
  cluster_ca_certificate = "${module.spin-k8s-cluster.cluster_ca_certificate}"
}
