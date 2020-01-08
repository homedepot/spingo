variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "grafana_ips_map" {
  type = map(string)
}

variable "grafana_hosts_map" {
  type = map(string)
}

variable "ship_plans" {
  type        = map(map(string))
  description = "The object that describes all of the clusters that need to be built by Spingo"
}
