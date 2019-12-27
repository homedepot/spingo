######################################################################################
# Required parameters
######################################################################################

variable "terraform_account" {
  type    = string
  default = "terraform-account"
}

variable "gcp_project" {
  description = "GCP project name"
}

variable "cloud_dns_hostname" {
  description = "This is the hostname that cloud dns will attach to. Note that a trailing period will be added."
}

