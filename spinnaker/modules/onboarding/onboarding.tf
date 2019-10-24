provider "google" {
  #   credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]

  credentials = file("terraform-account.json") //! swtich to this if you need to import stuff from GCP
  project     = var.gcp_project
}

resource "google_project_iam_custom_role" "onboarding_role" {
  role_id     = "onboarding_bucket_role"
  title       = "Onboarding bucket role"
  description = "This role will allow a user to upload onboarding information to the onboarding bucket but not be able to read anyone elses"
  permissions = ["storage.objects.list", "storage.objects.create"]
}

resource "google_storage_bucket" "onboarding_bucket" {
  name          = "${var.gcp_project}-spinnaker-onboarding"
  storage_class = "MULTI_REGIONAL"
  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.onboarding_bucket.name
  role   = "roles/storage.objectViewer"

  members = [
    "domain:${var.domain}:projects/${var.gcp_project}/roles/${google_project_iam_custom_role.onboarding_role.role_id}"
  ]
}

output "created_onboarding_bucket" {
  value = google_storage_bucket.onboarding_bucket.name
}
