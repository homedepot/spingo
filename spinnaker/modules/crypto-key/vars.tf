variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "kms_key_ring_self_link_map" {
  type        = map(string)
  description = "The self link of the created KeyRing in the format projects/{project}/locations/{location}/keyRings/{name}"
}

variable "ship_plans" {
  type        = map(map(string))
  description = "The object that describes all of the clusters that need to be built by Spingo"
}

variable "crypto_key_name_prefix" {
  type        = string
  description = "The prefix of the KMS key"
}
