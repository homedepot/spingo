######################################################################################
# Required parameters
######################################################################################

variable vault_address {
  type = "string"
}

variable terraform_account {
  type = "string"
}

variable "gcp_region" {
  description = "GCP region, e.g. us-east1"
  default     = "us-east1"
}

variable "gcp_project" {
  description = "GCP project name"
}

variable "cloud_dns_hostname" {
  description = "This is the hostname that cloud dns will attach to. Note that a trailing period will be added."
  default     = ".gcp.homedepot.com"
}
