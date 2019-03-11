provider "vault" {
  address = "${var.vault_address}"
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = "${data.vault_generic_secret.terraform-account.data[var.gcp_project]}"

  # credentials = "${file("terraform-account.json")}" //! swtich to this if you need to import stuff from GCP
  project = "${var.gcp_project}"
  region  = "${var.gcp_region}"
}

# Query the terraform service account from GCP
data "google_client_config" "current" {}

terraform {
  backend "gcs" {
    bucket      = "np-platforms-cd-thd-tf"
    prefix      = "np"
    credentials = "terraform-account.json"
  }
}

data "google_project" "project" {}

# TODO: This will eventually change when we get a dedicated domain for spinnaker.
resource "google_dns_managed_zone" "project_zone" {
  # see the vars file to an explination about this count thing
  count    = "${var.alter_dns}"
  name     = "${var.gcp_project}"
  dns_name = "${var.gcp_project}${var.cloud_dns_hostname}."
}

variable "cluster_config" {
  description = "This variable has been placed above the module declaration to facilitate easy changes between projects. The first index should always be the main cluster"

  default = {
    "0" = "spinnaker"
    "1" = "sandbox"
  }
}

module "spin-k8s-cluster" {
  source                          = "./modules/gke"
  cluster_name                    = "spinnaker"
  cluster_region                  = "${var.cluster_region}"
  gcp_project                     = "${var.gcp_project}"
  master_authorized_network_cidrs = []
  cluster_config                  = "${var.cluster_config}"
  dns_name                        = "${var.gcp_project}${var.cloud_dns_hostname}."
}

module "halyard-storage" {
  source      = "./modules/gcp-bucket"
  gcp_project = "${var.gcp_project}"
  bucket_name = "halyard"
}

provider "kubernetes" {
  alias                  = "main"
  load_config_file       = false
  host                   = "${element(module.spin-k8s-cluster.hosts, 0)}"
  cluster_ca_certificate = "${base64decode(element(module.spin-k8s-cluster.cluster_ca_certificates, 0))}"
  token                  = "${data.google_client_config.current.access_token}"
}

provider "kubernetes" {
  load_config_file       = false
  host                   = "${element(module.spin-k8s-cluster.hosts, 1)}"
  cluster_ca_certificate = "${base64decode(element(module.spin-k8s-cluster.cluster_ca_certificates, 1))}"
  token                  = "${data.google_client_config.current.access_token}"
  alias                  = "sandbox"
}

module "k8s-spinnaker-service-account" {
  source                    = "./modules/gke/k8s-service-account"
  service_account_name      = "spinnaker"
  service_account_namespace = "kube-system"
  bucket_name               = "${module.halyard-storage.bucket_name}"
  gcp_project               = "${var.gcp_project}"
  cluster_names             = "${module.spin-k8s-cluster.cluster_names}"
  cluster_config            = "${module.spin-k8s-cluster.cluster_config}"
  cluster_region            = "${module.spin-k8s-cluster.cluster_region}"
  hosts                     = "${module.spin-k8s-cluster.hosts}"
  cluster_ca_certificates   = "${module.spin-k8s-cluster.cluster_ca_certificates}"
  enable                    = "${length(var.cluster_config) >= 1 ? 1 : 0}"
  cluster_list_index        = 0

  providers = {
    kubernetes = "kubernetes.main"
  }
}

module "k8s-spinnaker-service-account-sandbox" {
  source                    = "./modules/gke/k8s-service-account"
  service_account_name      = "spinnaker"
  service_account_namespace = "kube-system"
  bucket_name               = "${module.halyard-storage.bucket_name}"
  gcp_project               = "${var.gcp_project}"
  cluster_names             = "${module.spin-k8s-cluster.cluster_names}"
  cluster_config            = "${module.spin-k8s-cluster.cluster_config}"
  cluster_region            = "${module.spin-k8s-cluster.cluster_region}"
  hosts                     = "${module.spin-k8s-cluster.hosts}"
  cluster_ca_certificates   = "${module.spin-k8s-cluster.cluster_ca_certificates}"
  enable                    = "${length(var.cluster_config) >= 2 ? 1 : 0}"
  cluster_list_index        = 1

  providers = {
    kubernetes = "kubernetes.sandbox"
  }
}

# to retrieve the keys for this for use outside of terraform, run 
# `vault read -format json -field=data secret/spinnaker-gcs-account > somefile.json`
module "spinnaker-gcp-service-account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "spinnaker-gcs-account"
  vault_address        = "${var.vault_address}"
  bucket_name          = "${module.halyard-storage.bucket_name}"
  gcp_project          = "${var.gcp_project}"
}
