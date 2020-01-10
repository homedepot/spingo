variable "gcp_project" {
  description = "GCP project name"
  type        = string
}

variable "managed_dns_gcp_project" {
  description = "GCP project name where the DNS managed zone lives"
  type        = string
}

variable "gcp_zone" {
  description = "GCP zone to create the halyard VM in"
  type        = string
}

variable "bucket_name" {
  description = "GCP Bucket for Halyard"
  default     = "-halyard-bucket"
}

variable "service_account_name" {
  description = "spinnaker service account to run on halyard vm"
  default     = "spinnaker"
}

variable "certbot_email" {
  description = "email account to be informed when certificates from certbot expire"
  type        = string
}

variable "terraform_account" {
  type    = string
  default = "terraform-account"
}

variable "auto_start_halyard_quickstart" {
  type        = bool
  default     = true
  description = "Auto run quickstart script on halyard vm if never run before"
}

variable "cloud_dns_hostname" {
  description = "This is the hostname that cloud dns will attach to. Note that a trailing period will be added."
  type        = string
}

variable "gcp_admin_email" {
  description = "This is the email of an administrator of the Google Cloud Project Organization. Possibly the one who granted the directory group read-only policy to the spinnaker-fiat service account"
  type        = string
}

variable "spingo_user_email" {
  description = "This is the is the email address of the person who first executed spingo for this project extracted from their gcloud login"
  type        = string
}

variable "spinnaker_admin_group" {
  description = "This is the role (group) that all the Spinnaker admins are members of. Change this to whatever is the correct group for the platform operators"
  type        = string
  default     = "gg_spinnaker_admins"
}

variable "spinnaker_admin_slack_channel" {
  description = "This is the channel to be used to alert the Spinnaker platform admins that new deployment targets need to be onboarded"
  type        = string
  default     = "spinnaker_admins"
}

variable "use_local_credential_file" {
  type    = bool
  default = false
}
