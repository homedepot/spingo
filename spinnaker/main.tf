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
  region  = var.cluster_region
}

provider "google" {
  alias       = "dns-zone"
  credentials = data.vault_generic_secret.terraform-account.data[var.managed_dns_gcp_project]

  # credentials = file("terraform-account.json") //! swtich to this if you need to import stuff from GCP
  project = var.managed_dns_gcp_project
  region  = var.cluster_region
}

provider "google-beta" {
  credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]

  # credentials = file("terraform-account.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
  region  = var.cluster_region
}

# Query the terraform service account from GCP
data "google_client_config" "current" {
}

data "google_project" "project" {
}

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
  cluster_region            = var.cluster_region
  gcp_project               = var.gcp_project
  cluster_config            = var.cluster_config
  authorized_networks_redis = [module.k8s.network_link, module.k8s-sandbox.network_link]
}

module "k8s" {
  source          = "github.com/devorbitus/terraform-google-gke-infra"
  name            = "${var.cluster_config["0"]}-${var.cluster_region}"
  project         = var.gcp_project
  region          = var.cluster_region
  private_cluster = true # This will disable public IPs from the nodes

  networks_that_can_access_k8s_api = compact(flatten([var.default_networks_that_can_access_k8s_api, [formatlist("%s/32", data.google_compute_address.halyard_ip_address.address)]]))

  oauth_scopes              = var.default_oauth_scopes
  k8s_options               = var.default_k8s_options
  node_options              = var.default_node_options
  node_metadata             = var.default_node_metadata
  client_certificate_config = var.default_client_certificate_config
  cloud_nat_address_name    = "${var.cluster_config["0"]}-${var.cluster_region}-nat"

}

module "k8s-sandbox" {
  source          = "github.com/devorbitus/terraform-google-gke-infra"
  name            = "${var.cluster_config["1"]}-${var.cluster_region}"
  project         = var.gcp_project
  region          = var.cluster_region
  private_cluster = true # This will disable public IPs from the nodes

  networks_that_can_access_k8s_api = compact(flatten([var.default_networks_that_can_access_k8s_api, [formatlist("%s/32", data.google_compute_address.halyard_ip_address.address)]]))

  oauth_scopes              = var.default_oauth_scopes
  k8s_options               = var.default_k8s_options
  node_options              = var.default_node_options
  node_metadata             = var.default_node_metadata
  client_certificate_config = var.default_client_certificate_config
  cloud_nat_address_name    = "${var.cluster_config["1"]}-${var.cluster_region}-nat"

}

module "halyard-storage" {
  source      = "./modules/gcp-bucket"
  gcp_project = var.gcp_project
  bucket_name = "halyard"
}

provider "kubernetes" {
  alias                  = "main"
  load_config_file       = false
  host                   = module.k8s.endpoint
  cluster_ca_certificate = base64decode(module.k8s.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}

provider "kubernetes" {
  load_config_file       = false
  host                   = module.k8s-sandbox.endpoint
  cluster_ca_certificate = base64decode(module.k8s-sandbox.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
  alias                  = "sandbox"
}

resource "kubernetes_service_account" "tiller" {
  provider = "kubernetes.main"

  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }

  automount_service_account_token = true
}

resource "kubernetes_cluster_role_binding" "tiller" {
  provider = "kubernetes.main"

  metadata {
    name = "tiller"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "tiller"
    api_group = ""
    namespace = "kube-system"
  }
}

provider "helm" {
  alias           = "main"
  install_tiller  = true
  debug           = true
  service_account = kubernetes_service_account.tiller.metadata.0.name
  namespace       = kubernetes_service_account.tiller.metadata.0.namespace

  kubernetes {
    host                   = module.k8s.endpoint
    cluster_ca_certificate = base64decode(module.k8s.cluster_ca_certificate)
    token                  = data.google_client_config.current.access_token
    load_config_file       = false
  }
}

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "helm_release" "prometheus-operator" {
  provider = "helm.main"
  name       = "prometheus-operator"
  repository = data.helm_repository.stable.metadata.0.name
  chart      = "prometheus-operator"
  namespace  = "monitoring"

  set {
    name  = "coreDns.enabled"
    value = "false"
  }

  set {
    name  = "kubeDns.enabled"
    value = "true"
  }

  set_string {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "standard"
  }

  set_string {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "50Gi"
  }

  set_string {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName"
    value = "standard"
  }

  set_string {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
    value = "50Gi"
  }

  set_string {
    name  = "grafana.adminPassword"
    value = "admin"
  }

  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  depends_on = [
    kubernetes_cluster_role_binding.tiller, 
    kubernetes_service_account.tiller
  ]

}

resource "kubernetes_service_account" "tiller-sandbox" {
  provider = "kubernetes.sandbox"

  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }

  automount_service_account_token = true
}

resource "kubernetes_cluster_role_binding" "tiller-sandbox" {
  provider = "kubernetes.sandbox"

  metadata {
    name = "tiller"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "tiller"
    api_group = ""
    namespace = "kube-system"
  }
}

provider "helm" {
  alias           = "sandbox"
  install_tiller  = true
  debug           = true
  service_account = kubernetes_service_account.tiller-sandbox.metadata.0.name
  namespace       = kubernetes_service_account.tiller-sandbox.metadata.0.namespace

  kubernetes {
    host                   = module.k8s-sandbox.endpoint
    cluster_ca_certificate = base64decode(module.k8s-sandbox.cluster_ca_certificate)
    token                  = data.google_client_config.current.access_token
    load_config_file       = false
  }
}

resource "helm_release" "prometheus-operator-sandbox" {
  provider = "helm.sandbox"
  name       = "prometheus-operator"
  repository = data.helm_repository.stable.metadata.0.name
  chart      = "prometheus-operator"
  namespace  = "monitoring"

  set {
    name  = "coreDns.enabled"
    value = "false"
  }

  set {
    name  = "kubeDns.enabled"
    value = "true"
  }

  set_string {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "standard"
  }

  set_string {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "50Gi"
  }

  set_string {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName"
    value = "standard"
  }

  set_string {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
    value = "50Gi"
  }

  set_string {
    name  = "grafana.adminPassword"
    value = "admin"
  }

  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  depends_on = [
    kubernetes_cluster_role_binding.tiller-sandbox, 
    kubernetes_service_account.tiller-sandbox
  ]

}

module "k8s-spinnaker-service-account" {
  source                    = "./modules/k8s-service-account"
  service_account_name      = "spinnaker"
  service_account_namespace = "kube-system"
  bucket_name               = module.halyard-storage.bucket_name
  gcp_project               = var.gcp_project
  cluster_name              = var.cluster_config["0"]
  cluster_config            = var.cluster_config
  cluster_region            = var.cluster_region
  host                      = module.k8s.endpoint
  cluster_ca_certificate    = module.k8s.cluster_ca_certificate
  enable                    = true
  cluster_list_index        = 0

  providers = {
    kubernetes = kubernetes.main
  }
}

module "k8s-spinnaker-service-account-sandbox" {
  source                    = "./modules/k8s-service-account"
  service_account_name      = "spinnaker"
  service_account_namespace = "kube-system"
  bucket_name               = module.halyard-storage.bucket_name
  gcp_project               = var.gcp_project
  cluster_name              = var.cluster_config["1"]
  cluster_config            = var.cluster_config
  cluster_region            = var.cluster_region
  host                      = module.k8s-sandbox.endpoint
  cluster_ca_certificate    = module.k8s-sandbox.cluster_ca_certificate
  enable                    = true
  cluster_list_index        = 1

  providers = {
    kubernetes = kubernetes.sandbox
  }
}

resource "kubernetes_namespace" "spinnaker" {
  provider = kubernetes.main
  metadata {
    name = "spinnaker"
  }
}

resource "kubernetes_secret" "secret" {
  provider = kubernetes.main
  metadata {
    name      = "cloudsql-instance-credentials"
    namespace = "spinnaker"
  }

  data = {
    secret = base64decode(module.spinnaker-gcp-cloudsql-service-account.service-account-json)
  }

  depends_on = [
    kubernetes_namespace.spinnaker
  ]
}

resource "kubernetes_namespace" "spinnaker_sandbox" {
  provider = kubernetes.sandbox
  metadata {
    name = "spinnaker"
  }
}

resource "kubernetes_secret" "secret_sandbox" {
  provider = kubernetes.sandbox
  metadata {
    name      = "cloudsql-instance-credentials"
    namespace = "spinnaker"
  }

  data = {
    secret = base64decode(module.spinnaker-gcp-cloudsql-service-account.service-account-json)
  }

  depends_on = [
    kubernetes_namespace.spinnaker_sandbox
  ]
}

# to retrieve the keys for this for use outside of terraform, run 
# `vault read -format json -field=data secret/spinnaker-gcs-account > somefile.json`
module "spinnaker-gcp-service-account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "spinnaker-gcs-account"
  bucket_name          = module.halyard-storage.bucket_name
  gcp_project          = var.gcp_project
  roles                = ["roles/storage.admin", "roles/browser"]
}

module "spinnaker-gcp-cloudsql-service-account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "spinnaker-cloudsql-account"
  bucket_name          = module.halyard-storage.bucket_name
  gcp_project          = var.gcp_project
  roles                = ["roles/cloudsql.client"]
}

data "google_compute_address" "halyard_ip_address" {
  name = "halyard-external-ip"
}

data "google_compute_address" "ui_ip_address" {
  name = "spinnaker-ui"
}

data "google_compute_address" "api_ip_address" {
  name = "spinnaker-api"
}

data "google_compute_address" "sandbox_ui_ip_address" {
  name = "sandbox-ui"
}

data "google_compute_address" "sandbox_api_ip_address" {
  name = "sandbox-api"
}

module "spinnaker-dns" {
  source           = "./modules/dns"
  gcp_project      = var.managed_dns_gcp_project
  cluster_config   = var.hostname_config
  dns_name         = "${var.cloud_dns_hostname}."
  ui_ip_addresses  = [data.google_compute_address.ui_ip_address.address, data.google_compute_address.sandbox_ui_ip_address.address]
  api_ip_addresses = [data.google_compute_address.api_ip_address.address, data.google_compute_address.sandbox_api_ip_address.address]

  providers = {
    google = google.dns-zone
  }
}

