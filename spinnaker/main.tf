provider "vault" {
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]

  # credentials = file("${var.terraform_account}.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
  version = "~> 2.8"
}

provider "google" {
  alias       = "dns-zone"
  credentials = data.vault_generic_secret.terraform-account.data[var.managed_dns_gcp_project]

  # credentials = file("${var.terraform_account}.json") //! swtich to this if you need to import stuff from GCP
  project = var.managed_dns_gcp_project
  version = "~> 2.8"
}

provider "google-beta" {
  credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]

  # credentials = file("${var.terraform_account}.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
  version = "~> 2.8"
}

data "terraform_remote_state" "static_ips" {
  backend = "gcs"

  config = {
    bucket      = "${var.gcp_project}-tf"
    credentials = "${var.terraform_account}.json" # this has to be a direct file location because it is needed before interpolation
    prefix      = "spingo-static-ips"
  }
}

data "terraform_remote_state" "dns" {
  backend = "gcs"

  config = {
    bucket      = "${var.gcp_project}-tf"
    credentials = "${var.terraform_account}.json" # this has to be a direct file location because it is needed before interpolation
    prefix      = "spingo-dns"
  }
}

# Query the terraform service account from GCP
data "google_client_config" "current" {
}

data "google_project" "project" {
}

module "k8s" {
  source          = "./modules/k8s"
  project         = var.gcp_project
  private_cluster = true # This will disable public IPs from the nodes

  networks_that_can_access_k8s_api = sort(compact(flatten([var.default_networks_that_can_access_k8s_api, [formatlist("%s/32", [trimspace(data.http.local_outgoing_ip_address.body)])], [formatlist("%s/32", data.terraform_remote_state.static_ips.outputs.halyard_ip)]])))

  oauth_scopes              = var.default_oauth_scopes
  k8s_options               = var.default_k8s_options
  node_options              = var.default_node_options
  node_metadata             = var.default_node_metadata
  client_certificate_config = var.default_client_certificate_config
  create_namespace          = var.default_create_namespace
  extras                    = var.extras
  crypto_key_id_map         = module.gke_keys.crypto_key_id_map
  ship_plans                = data.terraform_remote_state.static_ips.outputs.ship_plans
  cloudnat_name_map         = data.terraform_remote_state.static_ips.outputs.cloudnat_name_map
}

module "gke_keyring" {
  source                   = "./modules/kms_key_ring"
  kms_key_ring_cluster_map = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : v["clusterRegion"] => k... }
  kms_key_ring_prefix      = "gke_keyring"
}

module "gke_keys" {
  source                     = "./modules/crypto_key"
  gcp_project                = var.gcp_project
  kms_key_ring_self_link_map = module.gke_keyring.kms_key_ring_region_map
  ship_plans                 = data.terraform_remote_state.static_ips.outputs.ship_plans
  crypto_key_name_prefix     = "gke_key"
}

module "halyard-storage" {
  source      = "./modules/gcp-bucket"
  bucket_name = "${var.gcp_project}-halyard-bucket"
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

module "spinnaker-gcp-fiat-service-account" {
  source                 = "./modules/gcp-service-account"
  service_account_name   = "spinnaker-fiat"
  service_account_prefix = ""
  bucket_name            = module.halyard-storage.bucket_name
  gcp_project            = var.gcp_project
  roles                  = []
}

data "http" "local_outgoing_ip_address" {
  url = "https://ifconfig.me"
}

module "spinnaker-dns" {
  source             = "./modules/dns"
  gcp_project        = var.managed_dns_gcp_project
  ui_ip_addresses    = data.terraform_remote_state.static_ips.outputs.ui_ips_map
  api_ip_addresses   = data.terraform_remote_state.static_ips.outputs.api_ips_map
  x509_ip_addresses  = data.terraform_remote_state.static_ips.outputs.api_x509_ips_map
  vault_ip_addresses = data.terraform_remote_state.static_ips.outputs.vault_ips_map
  ship_plans         = data.terraform_remote_state.static_ips.outputs.ship_plans

  providers = {
    google = google.dns-zone
  }
}

module "onboarding-storage" {
  source      = "./modules/gcp-bucket"
  bucket_name = "${var.gcp_project}-spinnaker-onboarding"
}

resource "google_project_iam_custom_role" "onboarding_role" {
  role_id     = "onboarding_role"
  title       = "Onboarding Submitter Role"
  description = "This role will allow an authorized user to upload onboarding credentials to the onboarding bucket but not be able to read anyone elses"
  permissions = ["storage.objects.list", "storage.objects.create"]
}

resource "google_storage_bucket_iam_binding" "binding" {
  bucket = module.onboarding-storage.bucket_name
  role   = "projects/${var.gcp_project}/roles/${google_project_iam_custom_role.onboarding_role.role_id}"

  members = [
    "domain:${replace(var.spingo_user_email, "/^.*@/", "")}"
  ]
}

module "onboarding_gke" {
  source                     = "./modules/onboarding"
  gcp_project                = var.gcp_project
  onboarding_bucket_resource = module.onboarding-storage.bucket_resource
  storage_object_name_prefix = "gke"
}

module "onboarding-pubsub-service-account" {
  source                 = "./modules/gcp-service-account"
  service_account_name   = "onboarding-pub-sub"
  service_account_prefix = ""
  bucket_name            = module.halyard-storage.bucket_name
  gcp_project            = var.gcp_project
  roles                  = ["roles/storage.admin", "roles/pubsub.subscriber"]
}

module "halyard-service-account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "spinnaker-halyard"
  bucket_name          = module.halyard-storage.bucket_name
  gcp_project          = var.gcp_project
  roles = [
    "roles/storage.admin",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/container.admin",
    "roles/browser",
    "roles/container.clusterAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator"
  ]
}

resource "google_kms_crypto_key_iam_member" "halyard_encrypt_decrypt" {
  for_each      = data.terraform_remote_state.static_ips.outputs.ship_plans
  crypto_key_id = lookup(module.vault_keys.crypto_key_id_map, each.key, "")
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${module.halyard-service-account.service-account-email}"
}

module "certbot-service-account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "certbot"
  bucket_name          = module.halyard-storage.bucket_name
  gcp_project          = var.gcp_project
  roles                = ["roles/dns.admin"]
}

module "vault_keyring" {
  source                   = "./modules/kms_key_ring"
  kms_key_ring_cluster_map = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : v["clusterRegion"] => k... }
  kms_key_ring_prefix      = "vault_keyring"
}

module "vault_keys" {
  source                     = "./modules/crypto_key"
  gcp_project                = var.gcp_project
  kms_key_ring_self_link_map = module.vault_keyring.kms_key_ring_region_map
  ship_plans                 = data.terraform_remote_state.static_ips.outputs.ship_plans
  crypto_key_name_prefix     = "vault_key"
}

module "vault_setup" {
  source               = "./modules/vault"
  gcp_project          = var.gcp_project
  kms_keyring_name_map = module.vault_keyring.kms_key_ring_name_map
  vault_ips_map        = data.terraform_remote_state.static_ips.outputs.vault_ips_map
  crypto_key_id_map    = module.vault_keys.crypto_key_id_map
  ship_plans           = data.terraform_remote_state.static_ips.outputs.ship_plans
}

output "vault_keyring_name_map" {
  value = module.vault_keyring.kms_key_ring_name_map
}

output "vault_crypto_key_id_map" {
  value = module.vault_keys.crypto_key_id_map
}

output "vault_crypto_key_name_map" {
  value = module.vault_keys.crypto_key_name_map
}

output "vault_hosts_map" {
  value = module.spinnaker-dns.vault_hosts_map
}

output "vault_yml_files_map" {
  value = module.vault_setup.vault_yml_files_map
}

output "vault_bucket_name_map" {
  value = module.vault_setup.vault_bucket_name_map
}

output "created_onboarding_bucket_name" {
  value = module.onboarding-storage.bucket_name
}

output "spinnaker_fiat_account_unique_id" {
  value = module.spinnaker-gcp-fiat-service-account.service-account-id
}

output "redis_instance_link_map" {
  value = module.google-managed.redis_instance_link_map
}

output "the_gcp_project" {
  value = var.gcp_project
}

output "spinnaker-ui_hosts_map" {
  value = module.spinnaker-dns.ui_hosts_map
}

output "spinnaker-api_hosts_map" {
  value = module.spinnaker-dns.api_hosts_map
}

output "spinnaker-api_x509_hosts_map" {
  value = module.spinnaker-dns.api_x509_hosts_map
}

output "google_sql_database_instance_names_map" {
  value = module.google-managed.google_sql_database_instance_names_map
}

output "google_sql_database_failover_instance_names_map" {
  value = module.google-managed.google_sql_database_failover_instance_names_map
}

output "created_onboarding_topic_name" {
  value = module.onboarding_gke.created_onboarding_topic_name
}

output "created_onboarding_subscription_name" {
  value = module.onboarding_gke.created_onboarding_subscription_name
}

output "created_onboarding_service_account_name" {
  value = module.onboarding-pubsub-service-account.service-account-display-name
}

output "spinnaker_halyard_service_account_email" {
  value = module.halyard-service-account.service-account-email
}

output "spinnaker_halyard_service_account_display_name" {
  value = module.halyard-service-account.service-account-display-name
}

output "spinnaker_halyard_service_account_key_path" {
  value = module.halyard-service-account.service-account-key-path
}
