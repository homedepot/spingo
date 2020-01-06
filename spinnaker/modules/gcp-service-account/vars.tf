variable "service_account_name" {
  type = string
}

variable "service_account_prefix" {
  type    = string
  default = "svc"
}

variable "bucket_name" {
  type = string
}

variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "roles" {
  type = list(string)
}

variable "create_and_store_key" {
  type    = bool
  default = true
}
