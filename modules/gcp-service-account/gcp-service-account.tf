variable "service_account_name" {}

variable "vault_address" {
  type = "string"
}

variable "bucket_name" {
  type = "string"
}

variable "gcp_project" {
  description = "GCP project name"
}

resource "google_service_account" "service_account" {
  display_name = "svc-${var.service_account_name}"
  account_id   = "svc-${var.service_account_name}"
}

resource "google_project_iam_member" "storage_admin" {
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "browser" {
  role   = "roles/browser"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_service_account_key" "svc_key" {
  service_account_id = "${google_service_account.service_account.name}"
}

provider "vault" {
  address = "${var.vault_address}"
}

resource "vault_generic_secret" "service-account-key" {
  path      = "secret/${var.gcp_project}/${var.service_account_name}"
  data_json = "${base64decode(google_service_account_key.svc_key.private_key)}"
}

resource "google_storage_bucket_object" "service_account_key_storage" {
  name         = ".gcp/${var.service_account_name}.json"
  content      = "${base64decode(google_service_account_key.svc_key.private_key)}"
  bucket       = "${var.bucket_name}"
  content_type = "application/json"
}

output "service-account-id" {
  value = "${google_service_account.service_account.unique_id}"
}

output "service-account-name" {
  value = "${google_service_account.service_account.name}"
}

output "service-account-email" {
  value = "${google_service_account.service_account.email}"
}
