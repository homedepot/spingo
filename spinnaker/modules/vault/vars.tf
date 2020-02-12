variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "kms_keyring_name_map" {
  type        = map(string)
  description = "The name of the Cloud KMS KeyRing for asset encryption."
}


variable "crypto_key_id_map" {
  type = map(string)
}

variable "ship_plans" {
  type        = map(map(string))
  description = "The object that describes all of the clusters that need to be built by Spingo"
}

variable "service_account_email_map" {
  type = map(string)
}

variable "allowed_cidrs" {
  type        = string
  description = "cidrs allowed to access vault"
}

variable "vault_hosts_map" {
  type        = map(string)
  description = "hosts for vault"
}
