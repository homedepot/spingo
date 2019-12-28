resource "google_storage_bucket" "bucket" {
  name          = var.bucket_name
  storage_class = "MULTI_REGIONAL"
  versioning {
    enabled = true
  }
  force_destroy = true
}

output "bucket_name" {
  value = google_storage_bucket.bucket.name
}

output "bucket_resource" {
  value = google_storage_bucket.bucket
}
