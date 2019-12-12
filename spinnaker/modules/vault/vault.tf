resource "google_kms_crypto_key" "kms_key" {
  for_each        = var.cluster_key_map
  name            = "vault_key_${each.key}"
  key_ring        = var.kms_key_ring_self_link
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "100000s"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket" "vault" {
  for_each      = var.cluster_key_map
  name          = "vault_${var.gcp_project}_${each.key}"
  project       = var.gcp_project
  force_destroy = true
  storage_class = "MULTI_REGIONAL"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      num_newer_versions = 1
    }
  }
}

resource "google_storage_bucket_iam_member" "vault-server" {
  for_each = var.cluster_key_map
  bucket   = google_storage_bucket.vault[each.key].name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${each.key}@${var.gcp_project}.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "vault-init" {
  for_each      = var.cluster_key_map
  crypto_key_id = "projects/${var.gcp_project}/locations/${var.cluster_region}/keyRings/${var.kms_keyring_name}/cryptoKeys/vault_key_${each.key}"
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${each.key}@${var.gcp_project}.iam.gserviceaccount.com"
}

# Render the YAML file
data "template_file" "vault" {
  for_each = var.cluster_key_map
  template = file("${path.module}/vault.yml")

  vars = {
    gcs_bucket_name  = google_storage_bucket.vault[each.key].name
    kms_key_ring     = var.kms_keyring_name
    kms_crypto_key   = "vault_key_${each.key}"
    project          = var.gcp_project
    cluster_region   = var.cluster_region
    load_balancer_ip = lookup(var.vault_ips_map, each.key, "")
  }
}

output "vault_yml_files" {
  value = { for s in values(var.cluster_key_map) : s => base64encode(data.template_file.vault[s].rendered) }
}
