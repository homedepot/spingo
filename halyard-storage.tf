resource "google_storage_bucket" "halyard-config" {
  name          = "${var.gcp_project}-halyard-bucket"
  storage_class = "MULTI_REGIONAL"
}

data "google_project" "project" {}

# output "project_number" {
#   value = "${data.google_project.project.number}"
# } 

resource "google_storage_bucket_acl" "halyard-config-acl" {
  bucket = "${google_storage_bucket.halyard-config.name}"

  role_entity = [
    "OWNER:project-owners-${data.google_project.project.number}",
    "OWNER:project-editors-${data.google_project.project.number}"
  ]
}