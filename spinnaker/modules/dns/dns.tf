/*
Note: The Google Cloud DNS API requires NS records be present at all times. 
To accommodate this, when creating NS records, the default records Google 
automatically creates will be silently overwritten. Also, when destroying NS 
records, Terraform will not actually remove NS records, but will report that 
it did.
reference: https://www.terraform.io/docs/providers/google/r/dns_record_set.html
*/
resource "google_dns_record_set" "ui" {
  for_each     = var.ship_plans
  name         = "${each.value["deckSubdomain"]}${length(each.value["deckSubdomain"]) > 0 ? "." : ""}${each.value["wildcardDomain"]}."
  type         = "A"
  ttl          = 300
  managed_zone = "spinnaker-wildcard-domain"
  rrdatas      = [var.ui_ip_addresses[each.key]]
}

resource "google_dns_record_set" "api" {
  for_each     = var.ship_plans
  name         = "${each.value["gateSubdomain"]}.${each.value["wildcardDomain"]}."
  type         = "A"
  ttl          = 300
  managed_zone = "spinnaker-wildcard-domain"
  rrdatas      = [var.api_ip_addresses[each.key]]
}

resource "google_dns_record_set" "api_x509" {
  for_each     = var.ship_plans
  name         = "${each.value["x509Subdomain"]}.${each.value["wildcardDomain"]}."
  type         = "A"
  ttl          = 300
  managed_zone = "spinnaker-wildcard-domain"
  rrdatas      = [var.x509_ip_addresses[each.key]]
}

resource "google_dns_record_set" "vault" {
  for_each     = var.ship_plans
  name         = "${each.value["vaultSubdomain"]}.${each.value["wildcardDomain"]}."
  type         = "A"
  ttl          = 300
  managed_zone = "spinnaker-wildcard-domain"
  rrdatas      = [var.vault_ip_addresses[each.key]]
}

resource "google_dns_record_set" "grafana" {
  for_each     = var.ship_plans
  name         = "${each.value["grafanaSubdomain"]}.${each.value["wildcardDomain"]}."
  type         = "A"
  ttl          = 300
  managed_zone = "spinnaker-wildcard-domain"
  rrdatas      = [var.grafana_ip_addresses[each.key]]
}

resource "vault_generic_secret" "spinnaker_ui_address" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/spinnaker_ui_url/${each.key}"

  data_json = <<-EOF
              {"url":"${each.value["deckSubdomain"]}${length(each.value["deckSubdomain"]) > 0 ? "." : ""}${each.value["wildcardDomain"]}"}
EOF

}

resource "vault_generic_secret" "spinnaker_api_address" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/spinnaker_api_url/${each.key}"

  data_json = <<-EOF
              {"url":"${each.value["gateSubdomain"]}.${each.value["wildcardDomain"]}"}
EOF

}

resource "vault_generic_secret" "spinnaker_api_x509_address" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/spinnaker_api_x509_url/${each.key}"

  data_json = <<-EOF
              {"url":"${each.value["x509Subdomain"]}.${each.value["wildcardDomain"]}"}
EOF

}

resource "vault_generic_secret" "grafana_address" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/spinnaker_grafana_url/${each.key}"

  data_json = <<-EOF
              {"url":"${each.value["grafanaSubdomain"]}.${each.value["wildcardDomain"]}"}
EOF

}


output "ui_hosts_map" {
  value = { for k, v in var.ship_plans : k => "${v["deckSubdomain"]}${length(v["deckSubdomain"]) > 0 ? "." : ""}${v["wildcardDomain"]}" }
}

output "api_hosts_map" {
  value = { for k, v in var.ship_plans : k => "${v["gateSubdomain"]}.${v["wildcardDomain"]}" }
}

output "api_x509_hosts_map" {
  value = { for k, v in var.ship_plans : k => "${v["x509Subdomain"]}.${v["wildcardDomain"]}" }
}

output "vault_hosts_map" {
  value = { for k, v in var.ship_plans : k => "${v["vaultSubdomain"]}.${v["wildcardDomain"]}" }
}

output "grafana_hosts_map" {
  value = { for k, v in var.ship_plans : k => "${v["grafanaSubdomain"]}.${v["wildcardDomain"]}" }
}
