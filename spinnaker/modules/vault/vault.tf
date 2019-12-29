resource "google_storage_bucket" "vault" {
  for_each      = var.ship_plans
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
  for_each = var.ship_plans
  bucket   = google_storage_bucket.vault[each.key].name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${each.key}@${var.gcp_project}.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "vault-init" {
  for_each      = var.ship_plans
  crypto_key_id = lookup(var.crypto_key_id_map, each.key, "")
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${each.key}@${var.gcp_project}.iam.gserviceaccount.com"
}

# Render the YAML file
data "template_file" "vault" {
  for_each = var.ship_plans
  template = file("${path.module}/vault.yml")

  vars = {
    gcs_bucket_name  = google_storage_bucket.vault[each.key].name
    kms_key_ring     = var.kms_keyring_name
    kms_crypto_key   = "vault_key_${each.key}"
    crypto_key_id    = lookup(var.crypto_key_id_map, each.key, "")
    project          = var.gcp_project
    cluster_region   = each.value["clusterRegion"]
    load_balancer_ip = lookup(var.vault_ips_map, each.key, "")
  }
}

output "vault_yml_files_map" {
  value = { for k, v in var.ship_plans : k => base64encode(data.template_file.vault[k].rendered) }
}
