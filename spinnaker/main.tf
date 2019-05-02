terraform {
  backend "gcs" {}
}

provider "vault" {}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = "${data.vault_generic_secret.terraform-account.data[var.gcp_project]}"

  # credentials = "${file("terraform-account.json")}" //! swtich to this if you need to import stuff from GCP
  project = "${var.gcp_project}"
  region  = "${var.cluster_region}"
}

provider "google" {
  alias       = "dns-zone"
  credentials = "${data.vault_generic_secret.terraform-account.data[var.managed_dns_gcp_project]}"

  # credentials = "${file("terraform-account-dns.json")}" //! swtich to this if you need to import stuff from GCP
  project = "${var.managed_dns_gcp_project}"
  region  = "${var.cluster_region}"
}

provider "google-beta" {
  credentials = "${data.vault_generic_secret.terraform-account.data[var.gcp_project]}"

  # credentials = "${file("terraform-account.json")}" //! swtich to this if you need to import stuff from GCP
  version = "~> 1.19"
  project = "${var.gcp_project}"
  region  = "${var.cluster_region}"
}

# Query the terraform service account from GCP
data "google_client_config" "current" {}

data "google_project" "project" {}

variable "cluster_config" {
  description = "This variable has been placed above the module declaration to facilitate easy changes between projects. The first index should always be the main cluster"

  default = {
    "0" = "spinnaker"
    "1" = "sandbox"
  }
}

variable "hostname_config" {
  description = "This variable has been placed above the module declaration to facilitate easy changes between projects. The first index should always be the main cluster"

  default = {
    "0" = "np"
    "1" = "sandbox"
  }
}

module "google-managed" {
  source                    = "./modules/google-managed"
  cluster_region            = "${var.cluster_region}"
  gcp_project               = "${var.gcp_project}"
  cluster_config            = "${var.cluster_config}"
  authorized_networks_redis = "${list(module.k8s.network_link, module.k8s-sandbox.network_link)}"
}

module "k8s" {
  source          = "github.com/devorbitus/terraform-google-gke-infra"
  name            = "${var.cluster_config["0"]}-${var.cluster_region}"
  project         = "${var.gcp_project}"
  region          = "${var.cluster_region}"
  private_cluster = true                                               # This will disable public IPs from the nodes

  networks_that_can_access_k8s_api = "${var.default_networks_that_can_access_k8s_api}" # Need to hardcode this until terraform v0.12

  oauth_scopes              = "${var.default_oauth_scopes}"
  k8s_options               = "${var.default_k8s_options}"
  node_options              = "${var.default_node_options}"
  node_metadata             = "${var.default_node_metadata}"
  client_certificate_config = "${var.default_client_certificate_config}"

  providers = {
    google = "google-beta"
  }
}

module "k8s-sandbox" {
  source          = "github.com/devorbitus/terraform-google-gke-infra"
  name            = "${var.cluster_config["1"]}-${var.cluster_region}"
  project         = "${var.gcp_project}"
  region          = "${var.cluster_region}"
  private_cluster = true                                               # This will disable public IPs from the nodes

  networks_that_can_access_k8s_api = "${var.default_networks_that_can_access_k8s_api}" # Need to hardcode this until terraform v0.12

  oauth_scopes              = "${var.default_oauth_scopes}"
  k8s_options               = "${var.default_k8s_options}"
  node_options              = "${var.default_node_options}"
  node_metadata             = "${var.default_node_metadata}"
  client_certificate_config = "${var.default_client_certificate_config}"

  providers = {
    google = "google-beta"
  }
}

module "halyard-storage" {
  source      = "./modules/gcp-bucket"
  gcp_project = "${var.gcp_project}"
  bucket_name = "halyard"
}

provider "kubernetes" {
  alias                  = "main"
  load_config_file       = false
  host                   = "${module.k8s.endpoint}"
  cluster_ca_certificate = "${base64decode(module.k8s.cluster_ca_certificate)}"
  token                  = "${data.google_client_config.current.access_token}"
}

provider "kubernetes" {
  load_config_file       = false
  host                   = "${module.k8s-sandbox.endpoint}"
  cluster_ca_certificate = "${base64decode(module.k8s-sandbox.cluster_ca_certificate)}"
  token                  = "${data.google_client_config.current.access_token}"
  alias                  = "sandbox"
}

module "k8s-spinnaker-service-account" {
  source                    = "./modules/k8s-service-account"
  service_account_name      = "spinnaker"
  service_account_namespace = "kube-system"
  bucket_name               = "${module.halyard-storage.bucket_name}"
  gcp_project               = "${var.gcp_project}"
  cluster_name              = "${var.cluster_config["0"]}"
  cluster_config            = "${var.cluster_config}"
  cluster_region            = "${var.cluster_region}"
  host                      = "${module.k8s.endpoint}"
  cluster_ca_certificate    = "${module.k8s.cluster_ca_certificate}"
  enable                    = "${length(var.cluster_config) >= 1 ? 1 : 0}"
  cluster_list_index        = 0

  providers = {
    kubernetes = "kubernetes.main"
  }
}

module "k8s-spinnaker-service-account-sandbox" {
  source                    = "./modules/k8s-service-account"
  service_account_name      = "spinnaker"
  service_account_namespace = "kube-system"
  bucket_name               = "${module.halyard-storage.bucket_name}"
  gcp_project               = "${var.gcp_project}"
  cluster_name              = "${var.cluster_config["1"]}"
  cluster_config            = "${var.cluster_config}"
  cluster_region            = "${var.cluster_region}"
  host                      = "${module.k8s-sandbox.endpoint}"
  cluster_ca_certificate    = "${module.k8s-sandbox.cluster_ca_certificate}"
  enable                    = "${length(var.cluster_config) >= 2 ? 1 : 0}"
  cluster_list_index        = 1

  providers = {
    kubernetes = "kubernetes.sandbox"
  }
}

module "k8s-cloudsql-service-account-secret" {
  source          = "./modules/k8s-secret"
  name            = "cloudsql-instance-credentials"
  namespace       = "spinnaker"
  secret-contents = "${module.spinnaker-gcp-cloudsql-service-account.service-account-json}"

  providers = {
    kubernetes = "kubernetes.main"
  }
}

module "k8s-cloudsql-service-account-secret-sandbox" {
  source          = "./modules/k8s-secret"
  name            = "cloudsql-instance-credentials"
  namespace       = "spinnaker"
  secret-contents = "${module.spinnaker-gcp-cloudsql-service-account.service-account-json}"

  providers = {
    kubernetes = "kubernetes.sandbox"
  }
}

# to retrieve the keys for this for use outside of terraform, run 
# `vault read -format json -field=data secret/spinnaker-gcs-account > somefile.json`
module "spinnaker-gcp-service-account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "spinnaker-gcs-account"
  bucket_name          = "${module.halyard-storage.bucket_name}"
  gcp_project          = "${var.gcp_project}"
  roles                = ["roles/storage.admin", "roles/browser"]
}

module "spinnaker-gcp-cloudsql-service-account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "spinnaker-cloudsql-account"
  bucket_name          = "${module.halyard-storage.bucket_name}"
  gcp_project          = "${var.gcp_project}"
  roles                = ["roles/cloudsql.client"]
}

module "spinnaker-dns" {
  source           = "./modules/dns"
  gcp_project      = "${var.managed_dns_gcp_project}"
  cluster_config   = "${var.hostname_config}"
  dns_name         = "${var.cloud_dns_hostname}."
  ui_ip_addresses  = "${module.google-managed.ui_ip_addresses}"
  api_ip_addresses = "${module.google-managed.api_ip_addresses}"

  providers = {
    google = "google.dns-zone"
  }
}
