output "cluster_name_map" {
  value = { for k, v in var.ship_plans : k => google_container_cluster.cluster[k].name }
}

output "kubeconfig" {
  sensitive = true
  value     = var.enable_legacy_kubeconfig ? local.legacy_kubeconfig : local.gcloud_kubeconfig
}

output "endpoint_map" {
  value = { for k, v in var.ship_plans : k => google_container_cluster.cluster[k].endpoint }
}

output "cluster_ca_certificate_map" {
  sensitive = true
  value     = { for k, v in var.ship_plans : k => google_container_cluster.cluster[k].master_auth[0].cluster_ca_certificate }
}

output "client_certificate_map" {
  sensitive = true
  value     = { for k, v in var.ship_plans : k => google_container_cluster.cluster[k].master_auth[0].client_certificate }
}

output "client_key_map" {
  sensitive = true
  value     = { for k, v in var.ship_plans : k => google_container_cluster.cluster[k].master_auth[0].client_key }
}

output "network_name_map" {
  value = { for k, v in var.ship_plans : k => google_compute_network.vpc[k].name }
}

output "network_link_map" {
  value = { for k, v in var.ship_plans : k => google_compute_network.vpc[k].self_link }
}

output "subnet_name_map" {
  value = { for k, v in var.ship_plans : k => google_compute_subnetwork.subnet[k].name }
}

output "k8s_ip_ranges" {
  value = var.k8s_ip_ranges
}

output "instace_urls_map" {
  value = { for k, v in var.ship_plans : k => google_container_cluster.cluster[k].instance_group_urls }
}

output "service_account_map" {
  value = var.service_account == "" ? { for k, v in var.ship_plans : k => google_service_account.sa[k].email } : { for k, v in var.ship_plans : k => var.service_account }
}

output "service_account_key_map" {
  value = var.service_account == "" ? { for k, v in var.ship_plans : k => google_service_account_key.sa_key[k].private_key } : { for k, v in var.ship_plans : k => "" }
}

output "cloud_nat_adddress_map" {
  value = { for k, v in var.ship_plans : k => data.google_compute_address.existing_nat[k].address }
}

output "created_nodepool_map" {
  value = { for k, v in var.ship_plans : k => google_container_node_pool.primary_pool[k] }
}

# Render Kubeconfig output template
# locals {
#   legacy_kubeconfig = <<KUBECONFIG

# apiVersion: v1
# kind: Config
# preferences: {}
# clusters:
# - cluster:
#     server: https://${google_container_cluster.cluster.endpoint}
#     certificate-authority-data: ${google_container_cluster.cluster.master_auth[0].cluster_ca_certificate}
#   name: gke-${var.name}
# users:
# - name: gke-${var.name}
#   user:
#     client-certificate-data: ${google_container_cluster.cluster.master_auth[0].client_certificate}
#     client-key-data: ${google_container_cluster.cluster.master_auth[0].client_key}
# contexts:
# - context:
#     cluster: gke-${var.name}
#     user: gke-${var.name}
#   name: gke-${var.name}
# current-context: gke-${var.name}

# KUBECONFIG

# }

# locals {
#   gcloud_kubeconfig = <<KUBECONFIG

# apiVersion: v1
# kind: Config
# preferences: {}
# clusters:
# - cluster:
#     server: https://${google_container_cluster.cluster.endpoint}
#     certificate-authority-data: ${google_container_cluster.cluster.master_auth[0].cluster_ca_certificate}
#   name: gke-${var.name}
# users:
# - name: gke-${var.name}
#   user:
#     auth-provider:
#       config:
#         cmd-args: config config-helper --format=json
#         cmd-path: "${var.gcloud_path}"
#         expiry-key: '{.credential.token_expiry}'
#         token-key: '{.credential.access_token}'
#       name: gcp
# contexts:
# - context:
#     cluster: gke-${var.name}
#     user: gke-${var.name}
#   name: gke-${var.name}
# current-context: gke-${var.name}

# KUBECONFIG

# }

