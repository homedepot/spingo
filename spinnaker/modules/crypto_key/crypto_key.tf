resource "google_kms_crypto_key" "kms_key" {
  for_each        = var.cluster_key_map
  name            = "${var.crypto_key_name_prefix}_${each.key}"
  key_ring        = var.kms_key_ring_self_link
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "100000s"

  lifecycle {
    prevent_destroy = true
  }
}

data "google_kms_crypto_key" "crypto_key" {
  for_each = var.cluster_key_map
  name     = google_kms_crypto_key.kms_key[each.key].name
  key_ring = var.kms_key_ring_self_link
}

output "crypto_key_id_map" {
  value = { for s in values(var.cluster_key_map) : s => data.google_kms_crypto_key.crypto_key[s].self_link }
}
