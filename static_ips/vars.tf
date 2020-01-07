######################################################################################
# Required parameters
######################################################################################

variable "terraform_account" {
  type    = string
  default = "terraform-account"
}

variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "region" {
  type        = string
  description = "the region where the IPs are created - this must be the same region as the rest of the spinnaker cluster configuration"
}

variable "ship_plans" {
  type        = map(map(string))
  description = "The object that describes all of the clusters that need to be built by Spingo"
}
