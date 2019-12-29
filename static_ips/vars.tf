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
      clusterPrefix  = "spinnaker"
      clusterRegion  = "us-central1"
      wildcardDomain = "thd-spingo14.spinnaker.homedepot.com"
      gateSubdomain  = "np-api"
      deckSubdomain  = "np"
      x509Subdomain  = "np-api-spin"
      vaultSubdomain = "vault-np"
    }
    sandbox-us-central1 = {
      clusterPrefix  = "sandbox"
      clusterRegion  = "us-central1"
      wildcardDomain = "thd-spingo14.spinnaker.homedepot.com"
      gateSubdomain  = "sandbox-api"
      deckSubdomain  = "sandbox"
      x509Subdomain  = "sandbox-api-spin"
      vaultSubdomain = "vault-sandbox"
    }
  }
}
