resource "google_service_account" "service_account" {
  display_name = "${var.service_account_prefix}${length(var.service_account_prefix) > 0 ? "-" : ""}${var.service_account_name}"
  account_id   = "${var.service_account_prefix}${length(var.service_account_prefix) > 0 ? "-" : ""}${var.service_account_name}"
}

resource "google_project_iam_member" "roles" {
  for_each = { for r in var.roles : r => r }
  role     = each.key
  member   = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_service_account_key" "svc_key" {
  service_account_id = google_service_account.service_account.name
}

resource "vault_generic_secret" "service_account_key" {
  path      = "secret/${var.gcp_project}/${var.service_account_name}"
  data_json = base64decode(google_service_account_key.svc_key.private_key)
}

resource "google_storage_bucket_object" "service_account_key_storage" {
  name         = ".gcp/${var.service_account_name}.json"
  content      = base64decode(google_service_account_key.svc_key.private_key)
  bucket       = var.bucket_name
  content_type = "application/json"
}

output "service_account_id" {
  value = google_service_account.service_account.unique_id
}

output "service_account_name" {
  value = google_service_account.service_account.name
}

output "service_account_display_name" {
  value = google_service_account.service_account.display_name
}

output "service_account_email" {
  value = google_service_account.service_account.email
}

output "service_account_json" {
  value = google_service_account_key.svc_key.private_key
}

output "service_account_key_path" {
  value = vault_generic_secret.service_account_key.path
}
