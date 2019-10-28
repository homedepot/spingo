variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "domain" {
  type        = string
  description = "The domain to restrict the onboarding bucket to for uploading defaults to the email domain of the spingo user"
}

variable "onboarding_bucket_resource" {
  description = "This is the terraform resource for the onboarding bucket"
}

variable "storage_object_name_prefix" {
  type        = string
  description = "Only objects starting with this prefix will trigger the pub sub notification"
}