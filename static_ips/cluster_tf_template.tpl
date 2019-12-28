
/*

This craziness needs to be done because at the moment Terraform Providers and Modules do not allow for duplication using for_each or count.
Once the ability exists to make multiple copies this code will be refactored and removed.

*/

%{ for deployment, details in deployments ~}

# =======================================================================================
# BEGIN SECTION for ${deployment}
# =======================================================================================

module "k8s-${deployment}" {
  source          = "github.com/devorbitus/terraform-google-gke-infra"
  name            = "${deployment}"
  project         = var.gcp_project
  region          = "${details.clusterRegion}"
  private_cluster = true # This will disable public IPs from the nodes

  networks_that_can_access_k8s_api = compact(flatten([var.default_networks_that_can_access_k8s_api, [formatlist("%s/32", [trimspace(data.http.local_outgoing_ip_address.body)])], [formatlist("%s/32", data.google_compute_address.halyard_ip_address.address)]]))

  oauth_scopes              = var.default_oauth_scopes
  k8s_options               = var.default_k8s_options
  node_options              = var.default_node_options
  node_metadata             = var.default_node_metadata
  node_tags                 = ["${deployment}"]
  client_certificate_config = var.default_client_certificate_config
  cloud_nat_address_name    = "nat-${deployment}"
  create_namespace          = var.default_create_namespace
  extras                    = var.extras
  crypto_key_id             = lookup(module.gke_keys.crypto_key_id_map, "${deployment}", "")
}

provider "kubernetes" {
  load_config_file       = false
  host                   = module.k8s-${deployment}.endpoint
  cluster_ca_certificate = base64decode(module.k8s-${deployment}.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
  alias                  = "${deployment}"
}

provider "kubernetes" {
  load_config_file       = false
  host                   = module.k8s-${deployment}-agent.endpoint
  cluster_ca_certificate = base64decode(module.k8s-${deployment}-agent.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
  alias                  = "${deployment}-agent"
}

module "k8s-spinnaker-service-account-${deployment}" {
  source                    = "./modules/k8s-service-account"
  service_account_name      = "spinnaker"
  service_account_namespace = "kube-system"
  bucket_name               = module.halyard-storage.bucket_name
  gcp_project               = var.gcp_project
  deployment                = "${deployment}"
  cluster_config            = var.cluster_config
  cluster_region            = "${details.clusterRegion}"
  host                      = module.k8s-${deployment}.endpoint
  cluster_ca_certificate    = module.k8s-${deployment}.cluster_ca_certificate
  enable                    = true
  cluster_list_index        = index(keys(data.terraform_remote_state.static_ips.outputs.ship_plans),"${deployment}")
  cloudsql_credentials      = module.spinnaker-gcp-cloudsql-service-account.service-account-json
  spinnaker_namespace       = length(module.k8s-${deployment}.created_namespace) > 0 ? module.k8s-${deployment}.created_namespace.0.metadata.0.name : var.default_create_namespace
  spinnaker_nodepool        = module.k8s-${deployment}.created_nodepool

  providers = {
    kubernetes = kubernetes.${deployment}
  }
}

module "k8s-${deployment}-agent" {
  source          = "github.com/devorbitus/terraform-google-gke-infra"
  name            = "${deployment}"
  project         = var.gcp_project
  region          = "${details.clusterRegion}"
  private_cluster = true # This will disable public IPs from the nodes

  networks_that_can_access_k8s_api = compact(flatten([var.default_networks_that_can_access_k8s_api, [formatlist("%s/32", [trimspace(data.http.local_outgoing_ip_address.body)])], [formatlist("%s/32", data.google_compute_address.halyard_ip_address.address)]]))

  oauth_scopes              = var.default_oauth_scopes
  k8s_options               = var.default_k8s_options
  node_metadata             = var.default_node_metadata
  node_options              = var.second_cluster_node_options
  node_pool_options         = var.second_cluster_node_pool_options
  client_certificate_config = var.default_client_certificate_config
  cloud_nat                 = false # Will re-use the cloud nat created by the primary cluster
  cloud_nat_address_name    = "nat-${deployment}"
  node_tags                 = ["${deployment}"] # Use the same network tags as primary cluster
  create_namespace          = var.default_create_namespace
  extras                    = var.extras
  crypto_key_id             = lookup(module.gke_keys.crypto_key_id_map, "${deployment}", "")
}

module "k8s-spinnaker-service-account-${details.clusterPrefix}-agent" {
  source                    = "./modules/k8s-service-account"
  service_account_name      = "spinnaker"
  service_account_namespace = "kube-system"
  bucket_name               = module.halyard-storage.bucket_name
  gcp_project               = var.gcp_project
  deployment                = "${deployment}"
  cluster_config            = var.cluster_config
  cluster_region            = "${details.clusterRegion}"
  host                      = module.k8s-${deployment}-agent.endpoint
  cluster_ca_certificate    = module.k8s-${deployment}-agent.cluster_ca_certificate
  enable                    = true
  cluster_list_index        = 1
  cloudsql_credentials      = module.spinnaker-gcp-cloudsql-service-account.service-account-json
  spinnaker_namespace       = length(module.k8s-${deployment}-agent.created_namespace) > 0 ? module.k8s-${deployment}-agent.created_namespace.0.metadata.0.name : var.default_create_namespace
  spinnaker_nodepool        = module.k8s-${deployment}-agent.created_nodepool

  providers = {
    kubernetes = kubernetes.${deployment}-agent
  }
}

# =======================================================================================
# END SECTION for ${deployment}
# =======================================================================================

%{ endfor ~}
