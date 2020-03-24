variable "ship_plans" {
  type        = map(map(string))
  description = "The object that describes all of the clusters that need to be built by Spingo"
}

variable "vault_hosts_map" {
  type        = map(string)
  description = "hosts for vault"
}
