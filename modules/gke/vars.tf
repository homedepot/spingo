variable "gcp_region" {
  description = "GCP region, e.g. us-east1"
  default     = "us-east1"
}

variable "gcp_project" {
  description = "GCP project name"
}

variable cluster_name {
  type = "string"
}

variable cluster_region {
  type = "string"
}

# This variable is used to control the interaction of terraform to the cloud DNS
# such that the DNS things aren't deleted during a destroy operation when desired.
# - On a terraform apply operation where the DNS does NOT exist, and we want it created
# change this value to 1
# - On a terraform apply operation where the DNS DOES exist, and we do not want the DNS
# altered, change this value to 0
# - On a terraform destroy operation where the DNS DOES exist, and we do not want the DNS
# removed, change this value to 0
# - On a terraform destroy operation where the DNS DOES exist, and we DO want the DNS
# removed, change this value to 1
variable "alter_dns" {
  description = "See the vars.tf file for a detailed comment about this variable"
  default = 0
}

######################################################################################
# Optional parameters
######################################################################################

variable min_node_count {
  default = 1
}

variable max_node_count {
  default = 5
}

variable machine_type {
  default = "n1-standard-4"
}

variable gke_version {
  default = "1.11.5-gke.5"
}

variable master_authorized_network_cidrs {
  default = [
    {
      cidr_block = "151.140.0.0/16"
    },
    {
      cidr_block = "165.130.0.0/16"
    },
    {
      cidr_block = "207.11.0.0/17"
    },
    {
      cidr_block = "50.207.28.8/29"
    },
    {
      cidr_block = "98.6.11.8/29"
    },
  ]
}

variable oauth_scopes {
  default = [
    "https://www.googleapis.com/auth/cloud_debugger",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/trace.append",
  ]
}

variable preemptible_pool {
  default = false
}

variable "logging_service" {
  type    = "string"
  default = "logging.googleapis.com/kubernetes"
}

variable "monitoring_service" {
  type    = "string"
  default = "monitoring.googleapis.com/kubernetes"
}
