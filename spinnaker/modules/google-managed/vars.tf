variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "authorized_networks_redis" {
  description = "The networks (self-link) that can connect to the memorystore instance"
  type        = map(string)
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

variable "ship_plans" {
  type        = map(map(string))
  description = "The object that describes all of the clusters that need to be built by Spingo"
}
