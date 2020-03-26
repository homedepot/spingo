provider "vault" {
}

data "vault_generic_secret" "terraform_account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

data "vault_generic_secret" "terraform_account_dns" {
  path = "secret/${var.managed_dns_gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = var.use_local_credential_file ? file("${var.terraform_account}.json") : data.vault_generic_secret.terraform_account.data[var.gcp_project]
  project     = var.gcp_project
  version     = "~> 2.8"
}

provider "google" {
  alias       = "dns-zone"
  credentials = var.use_local_credential_file ? file("${var.terraform_account}-dns.json") : data.vault_generic_secret.terraform_account_dns.data[var.managed_dns_gcp_project]
  project     = var.managed_dns_gcp_project
  version     = "~> 2.8"
}

provider "google-beta" {
  credentials = var.use_local_credential_file ? file("${var.terraform_account}.json") : data.vault_generic_secret.terraform_account.data[var.gcp_project]
  project     = var.gcp_project
  version     = "~> 2.8"
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

locals {
  full_ship_plan_keys = concat(keys(module.gke_keys.crypto_key_id_map), formatlist("%s-agent", keys(module.gke_keys.crypto_key_id_map)))
  pod_cidr_pool       = concat(cidrsubnets("10.0.0.0/12", 2, 2, 2, 2), cidrsubnets("172.16.0.0/12", 2, 2, 2, 2))
}

module "k8s" {
  source          = "./modules/k8s"
  project         = var.gcp_project
  private_cluster = true # This will disable public IPs from the nodes

  networks_that_can_access_k8s_api = sort(compact(flatten([var.default_networks_that_can_access_k8s_api, [formatlist("%s/32", [trimspace(data.http.local_outgoing_ip_address.body)])], [formatlist("%s/32", data.terraform_remote_state.static_ips.outputs.halyard_ip)]])))

  oauth_scopes              = var.default_oauth_scopes
  k8s_options               = var.default_k8s_options
  node_options_map          = zipmap(local.full_ship_plan_keys, concat([for s in keys(data.terraform_remote_state.static_ips.outputs.ship_plans) : var.default_node_options], [for s in keys(data.terraform_remote_state.static_ips.outputs.ship_plans) : var.second_cluster_node_options]))
  node_pool_options_map     = zipmap(local.full_ship_plan_keys, concat([for s in keys(data.terraform_remote_state.static_ips.outputs.ship_plans) : var.default_node_pool_options], [for s in keys(data.terraform_remote_state.static_ips.outputs.ship_plans) : var.second_cluster_node_pool_options]))
  node_metadata             = var.default_node_metadata
  client_certificate_config = var.default_client_certificate_config
  extras                    = var.extras
  crypto_key_id_map         = zipmap(concat(keys(module.gke_keys.crypto_key_id_map), formatlist("%s-agent", keys(module.gke_keys.crypto_key_id_map))), concat(values(module.gke_keys.crypto_key_id_map), values(module.gke_keys.crypto_key_id_map)))
  ship_plans                = zipmap(local.full_ship_plan_keys, concat(values(data.terraform_remote_state.static_ips.outputs.ship_plans), values(data.terraform_remote_state.static_ips.outputs.ship_plans)))
  ship_plans_without_agent  = data.terraform_remote_state.static_ips.outputs.ship_plans
  cloudnat_name_map         = zipmap(concat(keys(data.terraform_remote_state.static_ips.outputs.cloudnat_name_map), formatlist("%s-agent", keys(data.terraform_remote_state.static_ips.outputs.cloudnat_name_map))), concat(values(data.terraform_remote_state.static_ips.outputs.cloudnat_name_map), values(data.terraform_remote_state.static_ips.outputs.cloudnat_name_map)))
  cloudnat_ips              = data.terraform_remote_state.static_ips.outputs.cloudnat_ips
  service_account_iam_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer",
    "projects/${var.gcp_project}/roles/${google_project_iam_custom_role.vault_role.role_id}"
  ]
  k8s_ip_ranges_map = { for s in local.full_ship_plan_keys : s => {
    master_cidr = "172.16.${index(local.full_ship_plan_keys, s)}.0/28"     # Specifies a private RFC1918 block for the master's VPC. The master range must not overlap with any subnet in your cluster's VPC. The master and your cluster use VPC peering. Must be specified in CIDR notation and must be /28 subnet. See: https://www.terraform.io/docs/providers/google/r/container_cluster.html#master_ipv4_cidr_block 10.0.82.0/28
    pod_cidr    = local.pod_cidr_pool[index(local.full_ship_plan_keys, s)] # The IP address range of the kubernetes pods in this cluster.
    svc_cidr    = "10.19${index(local.full_ship_plan_keys, s)}.16.0/20"
    node_cidr   = "10.19${index(local.full_ship_plan_keys, s)}.0.0/22"
    }
  }
}

module "google_managed" {
  source                    = "./modules/google-managed"
  gcp_project               = var.gcp_project
  ship_plans                = data.terraform_remote_state.static_ips.outputs.ship_plans
  authorized_networks_redis = module.k8s.network_link_map
}

module "gke_keyring" {
  source                   = "./modules/kms-key-ring"
  kms_key_ring_cluster_map = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : v["clusterRegion"] => k... }
  kms_key_ring_prefix      = "gke_keyring"
}

module "gke_keys" {
  source                     = "./modules/crypto-key"
  gcp_project                = var.gcp_project
  kms_key_ring_self_link_map = module.gke_keyring.kms_key_ring_region_map
  ship_plans                 = data.terraform_remote_state.static_ips.outputs.ship_plans
  crypto_key_name_prefix     = "gke_key"
}

module "halyard_storage" {
  source      = "./modules/gcp-bucket"
  bucket_name = "${var.gcp_project}-halyard-bucket"
}

# to retrieve the keys for this for use outside of terraform, run 
# `vault read -format json -field=data secret/spinnaker-gcs-account > somefile.json`
module "spinnaker_gcp_service_account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "spinnaker-gcs-account"
  bucket_name          = module.halyard_storage.bucket_name
  gcp_project          = var.gcp_project
  roles                = ["roles/storage.admin", "roles/browser"]
}

module "spinnaker_gcp_cloudsql_service_account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "spinnaker-cloudsql-account"
  bucket_name          = module.halyard_storage.bucket_name
  gcp_project          = var.gcp_project
  roles                = ["roles/cloudsql.client"]
}

module "spinnaker_gcp_fiat_service_account" {
  source                 = "./modules/gcp-service-account"
  service_account_name   = "spinnaker-fiat"
  service_account_prefix = ""
  bucket_name            = module.halyard_storage.bucket_name
  gcp_project            = var.gcp_project
  roles                  = []
}

data "http" "local_outgoing_ip_address" {
  url = "https://ifconfig.me"
}

module "spinnaker_dns" {
  source               = "./modules/dns"
  gcp_project          = var.gcp_project
  ui_ip_addresses      = data.terraform_remote_state.static_ips.outputs.api_ips_map
  api_ip_addresses     = data.terraform_remote_state.static_ips.outputs.api_ips_map
  x509_ip_addresses    = data.terraform_remote_state.static_ips.outputs.api_x509_ips_map
  vault_ip_addresses   = data.terraform_remote_state.static_ips.outputs.api_ips_map
  ship_plans           = data.terraform_remote_state.static_ips.outputs.ship_plans
  grafana_ip_addresses = data.terraform_remote_state.static_ips.outputs.api_ips_map

  providers = {
    google = google.dns-zone
  }
}

module "onboarding_storage" {
  source      = "./modules/gcp-bucket"
  bucket_name = "${var.gcp_project}-spinnaker-onboarding"
}

resource "google_project_iam_custom_role" "onboarding_role" {
  role_id     = "onboarding_role"
  title       = "Onboarding Submitter Role"
  description = "This role will allow an authorized user to upload onboarding credentials to the onboarding bucket but not be able to read anyone elses"
  permissions = ["storage.objects.list", "storage.objects.create"]
}

resource "google_project_iam_custom_role" "vault_role" {
  role_id     = "vault_gcp_role"
  title       = "Vault SA Role"
  description = "This role will allow vault to verify everything it needs for gcp authentication"
  permissions = [
    "iam.serviceAccounts.get",
    "iam.serviceAccountKeys.get",
    "compute.instances.get",
    "compute.instanceGroups.list",
  ]
}

resource "google_storage_bucket_iam_binding" "binding" {
  bucket = module.onboarding_storage.bucket_name
  role   = "projects/${var.gcp_project}/roles/${google_project_iam_custom_role.onboarding_role.role_id}"

  members = [
    "domain:${replace(var.spingo_user_email, "/^.*@/", "")}"
  ]
}

module "onboarding_gke" {
  source                     = "./modules/onboarding"
  gcp_project                = var.gcp_project
  onboarding_bucket_resource = module.onboarding_storage.bucket_resource
  storage_object_name_prefix = "gke"
}

module "onboarding_pubsub_service_account" {
  source                 = "./modules/gcp-service-account"
  service_account_name   = "onboarding-pub-sub"
  service_account_prefix = ""
  bucket_name            = module.halyard_storage.bucket_name
  gcp_project            = var.gcp_project
  roles                  = ["roles/storage.admin", "roles/pubsub.subscriber"]
}

module "spinnaker_onboarding_service_account" {
  source                 = "./modules/gcp-service-account"
  service_account_name   = "spinnaker-onboarding"
  service_account_prefix = ""
  bucket_name            = module.halyard_storage.bucket_name
  gcp_project            = var.gcp_project
  roles = [
    "roles/container.admin",
    "roles/iam.serviceAccountTokenCreator"
  ]
  create_and_store_key = false
}

resource "google_service_account_iam_binding" "onboarding_workload_identity_binding" {
  service_account_id = module.spinnaker_onboarding_service_account.service_account_name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${module.k8s.workload_identity_namespace}[spinnaker/spinnaker-onboarding]",
  ]
}

resource "google_service_account_iam_binding" "k8s_sa_workload_identity_binding" {
  for_each           = data.terraform_remote_state.static_ips.outputs.ship_plans
  service_account_id = module.k8s.service_account_name_map[each.key]
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${module.k8s.workload_identity_namespace}[spinnaker/${each.key}]",
    "serviceAccount:${module.k8s.workload_identity_namespace}[vault/vault]",
  ]
}

resource "google_service_account_iam_binding" "k8s_sa_agent_workload_identity_binding" {
  for_each           = data.terraform_remote_state.static_ips.outputs.ship_plans
  service_account_id = module.k8s.service_account_name_map["${each.key}-agent"]
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${module.k8s.workload_identity_namespace}[spinnaker/${each.key}-agent]",
  ]
}

data "vault_generic_secret" "certbot_account" {
  path = "secret/${var.gcp_project != var.managed_dns_gcp_project ? var.managed_dns_gcp_project : var.gcp_project}/certbot"
}

resource "google_storage_bucket_object" "service_account_key_storage" {
  name         = ".gcp/certbot.json"
  content      = data.vault_generic_secret.certbot_account.data[var.gcp_project != var.managed_dns_gcp_project ? var.managed_dns_gcp_project : var.gcp_project]
  bucket       = module.halyard_storage.bucket_name
  content_type = "application/json"
}

module "halyard_service_account" {
  source               = "./modules/gcp-service-account"
  service_account_name = "spinnaker-halyard"
  bucket_name          = module.halyard_storage.bucket_name
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
  member        = "serviceAccount:${module.halyard_service_account.service_account_email}"
}

module "vault_keyring" {
  source                   = "./modules/kms-key-ring"
  kms_key_ring_cluster_map = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : v["clusterRegion"] => k... }
  kms_key_ring_prefix      = "vault_keyring"
}

module "vault_keys" {
  source                     = "./modules/crypto-key"
  gcp_project                = var.gcp_project
  kms_key_ring_self_link_map = module.vault_keyring.kms_key_ring_region_map
  ship_plans                 = data.terraform_remote_state.static_ips.outputs.ship_plans
  crypto_key_name_prefix     = "vault_key"
}

module "vault_setup" {
  source                    = "./modules/vault"
  gcp_project               = var.gcp_project
  kms_keyring_name_map      = module.vault_keyring.kms_key_ring_name_map
  crypto_key_id_map         = module.vault_keys.crypto_key_id_map
  ship_plans                = data.terraform_remote_state.static_ips.outputs.ship_plans
  service_account_email_map = module.k8s.service_account_map
  vault_hosts_map           = module.spinnaker_dns.vault_hosts_map
  allowed_cidrs             = join(",", concat(var.default_networks_that_can_access_k8s_api, data.terraform_remote_state.static_ips.outputs.cloudnat_ips, [data.terraform_remote_state.static_ips.outputs.halyard_ip]))
}

module "vault_agent_setup" {
  source                    = "./modules/vault-agent"
  ship_plans                = data.terraform_remote_state.static_ips.outputs.ship_plans
  vault_hosts_map           = module.spinnaker_dns.vault_hosts_map
}

resource "google_compute_firewall" "iap" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  name     = "${each.key}-cloud-iap-ssh"
  network  = module.k8s.network_link_map[each.key]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [
    "35.235.240.0/20"
  ]
}

resource "google_compute_firewall" "vault_agent_injector" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  name     = "${each.key}-vault-agent-injector"
  network  = module.k8s.network_link_map[each.key]

  allow {
    protocol = "tcp"
    ports = [
      "8080"
    ]
  }

  source_ranges = [
    module.k8s.master_ipv4_cidr_block_map[each.key],
    module.k8s.master_ipv4_cidr_block_map["${each.key}-agent"]
  ]

  target_tags = [
    each.key
  ]
}

module "metrics_setup" {
  source             = "./modules/metrics"
  gcp_project        = var.gcp_project
  grafana_hosts_map  = module.spinnaker_dns.grafana_hosts_map
  ship_plans         = data.terraform_remote_state.static_ips.outputs.ship_plans
  cloud_dns_hostname = var.cloud_dns_hostname
}

output "spinnaker_onboarding_service_account_email" {
  value = module.spinnaker_onboarding_service_account.service_account_email
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

output "vault_yml_files_map" {
  value = module.vault_setup.vault_yml_files_map
}

output "vault_agent_yml_files_map" {
  value = module.vault_agent_setup.vault_agent_yml_files_map
}

output "vault_bucket_name_map" {
  value = module.vault_setup.vault_bucket_name_map
}

output "halyard_network_name" {
  value = keys(module.k8s.network_name_map)[0]
}

output "halyard_subnetwork_name" {
  value = keys(module.k8s.subnet_name_map)[0]
}

output "created_onboarding_bucket_name" {
  value = module.onboarding_storage.bucket_name
}

output "spinnaker_fiat_account_unique_id" {
  value = module.spinnaker_gcp_fiat_service_account.service_account_id
}

output "redis_instance_link_map" {
  value = module.google_managed.redis_instance_link_map
}

output "the_gcp_project" {
  value = var.gcp_project
}


output "vault_hosts_map" {
  value = module.spinnaker_dns.vault_hosts_map
}

output "grafana_hosts_map" {
  value = module.spinnaker_dns.grafana_hosts_map
}
output "spinnaker_ui_hosts_map" {
  value = module.spinnaker_dns.ui_hosts_map
}

output "spinnaker_api_hosts_map" {
  value = module.spinnaker_dns.api_hosts_map
}

output "spinnaker_api_x509_hosts_map" {
  value = module.spinnaker_dns.api_x509_hosts_map
}

output "google_sql_database_instance_names_map" {
  value = module.google_managed.google_sql_database_instance_names_map
}

output "google_sql_database_failover_instance_names_map" {
  value = module.google_managed.google_sql_database_failover_instance_names_map
}

output "created_onboarding_topic_name" {
  value = module.onboarding_gke.created_onboarding_topic_name
}

output "created_onboarding_subscription_name" {
  value = module.onboarding_gke.created_onboarding_subscription_name
}

output "created_onboarding_service_account_name" {
  value = module.onboarding_pubsub_service_account.service_account_display_name
}

output "spinnaker_halyard_service_account_email" {
  value = module.halyard_service_account.service_account_email
}

output "spinnaker_halyard_service_account_display_name" {
  value = module.halyard_service_account.service_account_display_name
}

output "spinnaker_halyard_service_account_key_path" {
  value = module.halyard_service_account.service_account_key_path
}

output "metrics_yml_files_map" {
  value = module.metrics_setup.metrics_yml_files_map
}
