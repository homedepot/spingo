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
  default = {
    spinnaker-us-central1 = {
      cluster_prefix  = "spinnaker"
      cluster_region  = "us-central1"
      wildcard_domain = "thd-spingo13.spinnaker.homedepot.com"
      gate_subdomain  = "np-api"
      deck_subdomain  = "np"
      x509_subdomain  = "np-api-spin"
      vault_subdomain = "vault-np"
    }
    sandbox-us-central1 = {
      cluster_prefix  = "sandbox"
      cluster_region  = "us-central1"
      wildcard_domain = "thd-spingo13.spinnaker.homedepot.com"
      gate_subdomain  = "sandbox-api"
      deck_subdomain  = "sandbox"
      x509_subdomain  = "sandbox-api-spin"
      vault_subdomain = "vault-sandbox"
    }
  }
}
