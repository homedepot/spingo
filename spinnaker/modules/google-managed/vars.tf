variable "gcp_project" {
  description = "GCP project name"
}

variable cluster_region {
  type = "string"
}

variable "authorized_networks_redis" {
  description = "The networks that can connect to the memorystore instance"
  type        = "list"
}

variable "cluster_config" {
  type = "map"
}

variable "redis_config" {
  default = {
    "notify-keyspace-events" = "gxE"
  }

  description = "this default setting is necessary for gate to work with hosted redis services like memorystore"
}

variable cloudsql_machine_type {
  default = "db-n1-standard-2"
}
