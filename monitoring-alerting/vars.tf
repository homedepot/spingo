variable "terraform_account" {
  type    = string
  default = "terraform-account"
}

variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "notification_channels" {
  type        = list(string)
  description = "The list of notification channels that the policy alerts should be configured to send to SHOULD BE ADDED BY setupNotificationChannels script"
}

variable "use_local_credential_file" {
  type    = bool
  default = false
}
