variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "cluster_region" {
  type = string
}

variable "authorized_networks_redis" {
  description = "The networks (self-link) that can connect to the memorystore instance"
  type        = list(string)
}

variable "cluster_config" {
  type = map(string)
}

variable "redis_config" {
  type = map(string)
  default = {
    "notify-keyspace-events" = "gxE"
  }

  description = "this default setting is necessary for gate to work with hosted redis services like memorystore"
}

variable "cloudsql_machine_type" {
  type    = string
  default = "db-n1-standard-2"
}
