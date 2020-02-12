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

resource "google_storage_bucket_iam_member" "vault_server" {
  for_each = var.ship_plans
  bucket   = google_storage_bucket.vault[each.key].name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${var.service_account_email_map[each.key]}"
}

resource "google_kms_crypto_key_iam_member" "vault_init" {
  for_each      = var.ship_plans
  crypto_key_id = lookup(var.crypto_key_id_map, each.key, "")
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${var.service_account_email_map[each.key]}"
}

# Render the YAML file
data "template_file" "vault" {
  for_each = var.ship_plans
  template = file("${path.module}/vault.yaml")

  vars = {
    gcs_bucket_name        = google_storage_bucket.vault[each.key].name
    kms_key_ring           = var.kms_keyring_name_map[each.value["clusterRegion"]]
    kms_crypto_key         = "vault_key_${each.key}"
    crypto_key_id          = lookup(var.crypto_key_id_map, each.key, "")
    project                = var.gcp_project
    cluster_sa_email       = var.service_account_email_map[each.key]
    cluster_region         = each.value["clusterRegion"]
    vault_ui_hostname      = lookup(var.vault_hosts_map, each.key, "")
    whitelist_source_range = var.allowed_cidrs

  }
}

output "vault_yml_files_map" {
  value = { for k, v in var.ship_plans : k => base64encode(data.template_file.vault[k].rendered) }
}

output "vault_bucket_name_map" {
  value = { for k, v in var.ship_plans : k => google_storage_bucket.vault[k].name }
}
