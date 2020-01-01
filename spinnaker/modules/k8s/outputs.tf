output "cluster_name_map" {
  value = { for k, v in var.ship_plans : k => google_container_cluster.cluster[k].name }
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
  value = var.service_account == "" ? { for k, v in var.ship_plans_without_agent : k => google_service_account.sa[k].email } : { for k, v in var.ship_plans : k => var.service_account }
}

output "service_account_key_map" {
  value = var.service_account == "" ? { for k, v in var.ship_plans_without_agent : k => google_service_account_key.sa_key[k].private_key } : { for k, v in var.ship_plans : k => "" }
}

output "cloud_nat_adddress_map" {
  value = { for k, v in var.ship_plans : k => data.google_compute_address.existing_nat[k].address }
}

output "created_nodepool_map" {
  value = { for k, v in var.ship_plans : k => google_container_node_pool.primary_pool[k] }
}
