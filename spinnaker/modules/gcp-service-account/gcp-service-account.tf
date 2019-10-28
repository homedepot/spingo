variable "service_account_name" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "roles" {
  type = list(string)
}

resource "google_service_account" "service_account" {
  display_name = "svc-${var.service_account_name}"
  account_id   = "svc-${var.service_account_name}"
}

resource "google_project_iam_member" "roles" {
  count  = length(var.roles)
  role   = element(var.roles, count.index)
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_service_account_key" "svc_key" {
  service_account_id = google_service_account.service_account.name
}

resource "vault_generic_secret" "service-account-key" {
  path      = "secret/${var.gcp_project}/${var.service_account_name}"
  data_json = base64decode(google_service_account_key.svc_key.private_key)
}

resource "google_storage_bucket_object" "service_account_key_storage" {
  name         = ".gcp/${var.service_account_name}.json"
  content      = base64decode(google_service_account_key.svc_key.private_key)
  bucket       = var.bucket_name
  content_type = "application/json"
}

output "service-account-id" {
  value = google_service_account.service_account.unique_id
}

output "service-account-name" {
  value = google_service_account.service_account.name
}

output "service-account-display-name" {
  value = google_service_account.service_account.display_name
}

output "service-account-email" {
  value = google_service_account.service_account.email
}

output "service-account-json" {
  value = google_service_account_key.svc_key.private_key
}

