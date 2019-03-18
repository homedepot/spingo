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

variable "cluster_config" {
  type = "map"
}

variable "dns_name" {
  description = "description"
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

variable "redis_config" {
  default = {"notify-keyspace-events"="gxE"}
}
