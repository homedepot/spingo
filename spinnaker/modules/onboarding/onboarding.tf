
resource "google_pubsub_topic" "onboading_topic" {
  name = "spingo-onboarding-${var.storage_object_name_prefix}-topic"
}

resource "google_storage_notification" "onboarding_notification" {
  bucket             = var.onboarding_bucket_resource.name
  payload_format     = "JSON_API_V1"
  topic              = google_pubsub_topic.onboading_topic.name
  event_types        = ["OBJECT_FINALIZE"]
  object_name_prefix = "${var.storage_object_name_prefix}/"
  depends_on = [
    google_pubsub_topic_iam_binding.binding
  ]
}

// Enable notifications by giving the correct IAM permission to the unique service account.

data "google_storage_project_service_account" "gcs_account" {}

resource "google_pubsub_topic_iam_binding" "binding" {
  topic   = google_pubsub_topic.onboading_topic.name
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

// End enabling notifications

resource "google_pubsub_subscription" "onboarding_subscription" {
  name  = "spingo-onboarding-${var.storage_object_name_prefix}-subscription"
  topic = google_pubsub_topic.onboading_topic.name
}

output "created_onboarding_topic_name" {
  value = google_pubsub_topic.onboading_topic.name
}

output "created_onboarding_subscription_name" {
  value = google_pubsub_subscription.onboarding_subscription.name
}
