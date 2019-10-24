variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "domain" {
  type        = string
  description = "The domain to restrict the onboarding bucket to for uploading"
}