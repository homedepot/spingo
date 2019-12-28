provider "vault" {
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]

  # credentials = file("${var.terraform_account}.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
  region  = var.cluster_region
  version = "~> 2.8"
}

provider "google" {
  alias       = "dns-zone"
  credentials = data.vault_generic_secret.terraform-account.data[var.managed_dns_gcp_project]

  # credentials = file("${var.terraform_account}.json") //! swtich to this if you need to import stuff from GCP
  project = var.managed_dns_gcp_project
  region  = var.cluster_region
  version = "~> 2.8"
}

provider "google-beta" {
  credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]

  # credentials = file("${var.terraform_account}.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
  region  = var.cluster_region
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

resource "google_kms_key_ring" "gke_keyring" {
  name     = "gke_keyring"
  location = var.cluster_region
}

module "gke_keys" {
  source                 = "./modules/crypto_key"
  gcp_project            = var.gcp_project
  kms_key_ring_self_link = google_kms_key_ring.gke_keyring.self_link
  ship_plans             = data.terraform_remote_state.static_ips.outputs.ship_plans
  crypto_key_name_prefix = "gke_key"
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

resource "google_service_account" "spinnaker_oauth_fiat" {
  display_name = "spinnaker-fiat"
  account_id   = "spinnaker-fiat"
}

resource "google_service_account_key" "fiat_svc_key" {
  service_account_id = google_service_account.spinnaker_oauth_fiat.name
}

resource "vault_generic_secret" "fiat-service-account-key" {
  path      = "secret/${var.gcp_project}/spinnaker_fiat"
  data_json = base64decode(google_service_account_key.fiat_svc_key.private_key)
}

resource "google_storage_bucket_object" "fiat_service_account_key_storage" {
  name         = ".gcp/spinnaker-fiat.json"
  content      = base64decode(google_service_account_key.fiat_svc_key.private_key)
  bucket       = module.halyard-storage.bucket_name
  content_type = "application/json"
}

data "google_compute_address" "halyard_ip_address" {
  name = "halyard-external-ip"
}

data "http" "local_outgoing_ip_address" {
  url = "https://ifconfig.me"
}

module "spinnaker-dns" {
  source             = "./modules/dns"
  gcp_project        = var.managed_dns_gcp_project
  cluster_config     = var.hostname_config
  dns_name           = "${var.cloud_dns_hostname}"
  ui_ip_addresses    = data.terraform_remote_state.static_ips.outputs.ui_ips
  api_ip_addresses   = data.terraform_remote_state.static_ips.outputs.api_ips
  x509_ip_addresses  = data.terraform_remote_state.static_ips.outputs.api_x509_ips
  vault_ip_addresses = data.terraform_remote_state.static_ips.outputs.vault_ips
  ship_plans         = data.terraform_remote_state.static_ips.outputs.ship_plans

  providers = {
    google = google.dns-zone
  }
}

resource "google_storage_bucket" "onboarding_bucket" {
  name          = "${var.gcp_project}-spinnaker-onboarding"
  storage_class = "MULTI_REGIONAL"
  versioning {
    enabled = true
  }
}

resource "google_project_iam_custom_role" "onboarding_role" {
  role_id     = "onboarding_role"
  title       = "Onboarding Submitter Role"
  description = "This role will allow an authorized user to upload onboarding credentials to the onboarding bucket but not be able to read anyone elses"
  permissions = ["storage.objects.list", "storage.objects.create"]
}

resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.onboarding_bucket.name
  role   = "projects/${var.gcp_project}/roles/${google_project_iam_custom_role.onboarding_role.role_id}"

  members = [
    "domain:${replace(var.spingo_user_email, "/^.*@/", "")}"
  ]
}

module "onboarding_gke" {
  source                     = "./modules/onboarding"
  gcp_project                = var.gcp_project
  onboarding_bucket_resource = google_storage_bucket.onboarding_bucket
  storage_object_name_prefix = "gke"
}

module "onboarding-pubsub-service-account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "onboarding-pub-sub"
  bucket_name          = module.halyard-storage.bucket_name
  gcp_project          = var.gcp_project
  roles                = ["roles/storage.admin", "roles/pubsub.subscriber"]
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
  for_each      = zipmap(formatlist("%s-${var.cluster_region}", values(var.cluster_config)), formatlist("%s-${var.cluster_region}", values(var.cluster_config)))
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

resource "google_kms_key_ring" "vault_keyring" {
  name     = "vault_keyring"
  location = var.cluster_region
}

module "vault_keys" {
  source                 = "./modules/crypto_key"
  gcp_project            = var.gcp_project
  kms_key_ring_self_link = google_kms_key_ring.vault_keyring.self_link
  ship_plans             = data.terraform_remote_state.static_ips.outputs.ship_plans
  crypto_key_name_prefix = "vault_key"
}

module "vault_setup" {
  source                 = "./modules/vault"
  gcp_project            = var.gcp_project
  kms_key_ring_self_link = google_kms_key_ring.vault_keyring.self_link
  cluster_key_map        = zipmap(formatlist("%s-${var.cluster_region}", values(var.cluster_config)), formatlist("%s-${var.cluster_region}", values(var.cluster_config)))
  kms_keyring_name       = google_kms_key_ring.vault_keyring.name
  vault_ips_map          = data.terraform_remote_state.static_ips.outputs.vault_ips_map
  cluster_region         = var.cluster_region
  crypto_key_id_map      = module.vault_keys.crypto_key_id_map
}

output "vault_keyring" {
  value = google_kms_key_ring.vault_keyring.name
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

output "vault_yml_files" {
  value = module.vault_setup.vault_yml_files
}

output "created_onboarding_bucket_name" {
  value = google_storage_bucket.onboarding_bucket.name
}

output "spinnaker_fiat_account_unique_id" {
  value = google_service_account.spinnaker_oauth_fiat.unique_id
}

output "redis_instance_links" {
  value = module.google-managed.redis_instance_link
}

output "cluster_config_values" {
  value = values(var.cluster_config)
}

output "hostname_config_values" {
  value = values(var.hostname_config)
}

output "the_gcp_project" {
  value = var.gcp_project
}

output "spinnaker-ui_hosts" {
  value = module.spinnaker-dns.spinnaker-ui_hosts
}

output "spinnaker-api_hosts" {
  value = module.spinnaker-dns.spinnaker-api_hosts
}

output "spinnaker-api_x509_hosts" {
  value = module.spinnaker-dns.spinnaker-api_x509_hosts
}

output "google_sql_database_instance_names" {
  value = module.google-managed.google_sql_database_instance_names
}

output "google_sql_database_failover_instance_names" {
  value = module.google-managed.google_sql_database_failover_instance_names
}

output "cluster_region" {
  value = var.cluster_region
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
