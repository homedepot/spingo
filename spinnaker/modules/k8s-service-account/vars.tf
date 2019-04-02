variable host {
  type = "string"
}

variable cluster_name {
  type = "string"
}

variable cluster_region {
  type = "string"
}

variable gcp_project {
  type = "string"
}

variable bucket_name {
  type = "string"
}

variable "cluster_config" {
  type = "map"
}

variable "service_account_name" {}
variable "service_account_namespace" {}

variable cluster_ca_certificate {
  type = "string"
}

variable "cluster_list_index" {
  description = "index within list of cluster information"
}

# variable "kube_config_path_in_bucket" {
#   description = "path inside the project level halyard bucket where this kube config will get stored"
# }

variable "enable" {
  description = "specify if the resource should be enabled or not"
  default     = false
}
