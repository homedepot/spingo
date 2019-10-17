variable "host" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_region" {
  type = string
}

variable "gcp_project" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "cluster_config" {
  type = map(string)
}

variable "service_account_name" {
  type = string
}

variable "service_account_namespace" {
  type = string
}

variable "cluster_ca_certificate" {
  type = string
}

variable "cluster_list_index" {
  type        = number
  description = "index within list of cluster information"
}

# variable "kube_config_path_in_bucket" {
#   description = "path inside the project level halyard bucket where this kube config will get stored"
# }

variable "enable" {
  type        = bool
  description = "specify if the resource should be enabled or not"
  default     = false
}

variable "spinnaker_namespace" {
  type         = "string"
  description  = "namespace where spinnaker lives"
}

variable "cloudsql_credentials" {
  type         = string
  description  = "cloudsql instance service account credentials in json format"
}
