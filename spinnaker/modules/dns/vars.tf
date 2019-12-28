variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "cluster_config" {
  type = map(string)
}

variable "dns_name" {
  type        = string
  description = "description"
}

variable "ui_ip_addresses" {
  type = map(string)
}

variable "api_ip_addresses" {
  type = map(string)
}

variable "x509_ip_addresses" {
  type = map(string)
}

variable "vault_ip_addresses" {
  type = map(string)
}

variable "ship_plans" {
  type        = map(map(string))
  description = "The object that describes all of the clusters that need to be built by Spingo"
}
