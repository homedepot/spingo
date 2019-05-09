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
  type = list(string)
}

variable "api_ip_addresses" {
  type = list(string)
}

