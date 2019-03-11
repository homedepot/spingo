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

variable "cluster_region" {
  type        = "string"
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

# This variable is used to control the interaction of terraform to the cloud DNS
# such that the DNS things aren't deleted during a destroy operation when desired.
# - On a terraform apply operation where the DNS does NOT exist, and we want it created
# change this value to 1
# - On a terraform apply operation where the DNS DOES exist, and we do not want the DNS
# altered, change this value to 0
# - On a terraform destroy operation where the DNS DOES exist, and we do not want the DNS
# removed, change this value to 0
# - On a terraform destroy operation where the DNS DOES exist, and we DO want the DNS
# removed, change this value to 1
variable "alter_dns" {
  description = "See the vars.tf file for a detailed comment about this variable"
  default     = 0
}
