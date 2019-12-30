resource "google_kms_key_ring" "keyring" {
  for_each = var.kms_key_ring_cluster_map
  name     = "${var.kms_key_ring_prefix}_${each.key}"
  location = each.key
}

output "kms_key_ring_region_map" {
  value = { for k, v in var.kms_key_ring_cluster_map : k => google_kms_key_ring.keyring[k].self_link }
}

output "kms_key_ring_name_map" {
  value = { for k, v in var.kms_key_ring_cluster_map : k => google_kms_key_ring.keyring[k].name }
}
