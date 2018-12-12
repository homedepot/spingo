variable "gcp_project" {
  description = "GCP project name"
}

variable "bucket_name" {}

resource "google_storage_bucket" "bucket-config" {
  name          = "${var.gcp_project}-${var.bucket_name}-bucket"
  storage_class = "MULTI_REGIONAL"
}

# Not using the below for now.  The purpose of this block was to attempt to
# set bucket ACL permissions such that only project owners and editors
# had acccess to the created bucket. When we attempted to do this, the bucket
# appeared to get created with the regular default permissions.
# Keeping this below for future reference in case we want to re-visit


# resource "google_storage_bucket_acl" "halyard-config-acl" {
#   bucket = "${google_storage_bucket.halyard-config.name}"


#   role_entity = [
#     "OWNER:project-owners-${data.google_project.project.number}",
#     "OWNER:project-editors-${data.google_project.project.number}"
#   ]
# }

