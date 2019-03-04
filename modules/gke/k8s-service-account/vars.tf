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

variable "service_account_name" {}
variable "service_account_namespace" {}

variable client_certificate {}
variable client_key {}
variable cluster_ca_certificate {}
