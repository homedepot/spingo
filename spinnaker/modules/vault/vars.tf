variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "kms_key_ring_self_link" {
  type        = string
  description = "The self link of the created KeyRing in the format projects/[project}/locations/{location}/keyRings/{name}"
}

variable "cluster_key_map" {
  type        = map(string)
  description = "The keys of this map will dictate the names of the resources to be created and should be the cluster names"
}

variable "kms_keyring_name" {
  type        = string
  description = "The name of the Cloud KMS KeyRing for asset encryption."
}

variable "vault_ips_map" {
  type = map(string)
}

variable "cluster_region" {
  type = string
}

variable "crypto_key_id_map" {
  type = map(string)
}
