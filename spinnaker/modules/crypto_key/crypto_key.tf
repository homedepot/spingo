resource "google_kms_crypto_key" "kms_key" {
  for_each        = var.ship_plans
  name            = "${var.crypto_key_name_prefix}_${each.key}"
  key_ring        = var.kms_key_ring_self_link_map[each.value["clusterRegion"]]
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "100000s"

  lifecycle {
    prevent_destroy = true
  }
}

data "google_kms_crypto_key" "crypto_key" {
  for_each = var.ship_plans
  name     = google_kms_crypto_key.kms_key[each.key].name
  key_ring = var.kms_key_ring_self_link_map[each.value["clusterRegion"]]
}

output "crypto_key_id_map" {
  value = { for k, v in var.ship_plans : k => data.google_kms_crypto_key.crypto_key[k].self_link }
}

output "crypto_key_name_map" {
  value = { for k, v in var.ship_plans : k => data.google_kms_crypto_key.crypto_key[k].name }
}
