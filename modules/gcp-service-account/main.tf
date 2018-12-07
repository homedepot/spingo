variable "service_account_name" {}

resource "google_service_account" "service_account" {
  display_name = "svc-${var.service_account_name}"
  account_id   = "svc-${var.service_account_name}"
}

resource "google_project_iam_member" "storage_admin" {
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.service_account.email}"
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
