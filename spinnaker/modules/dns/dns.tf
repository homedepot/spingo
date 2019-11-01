/*
Note: The Google Cloud DNS API requires NS records be present at all times. 
To accommodate this, when creating NS records, the default records Google 
automatically creates will be silently overwritten. Also, when destroying NS 
records, Terraform will not actually remove NS records, but will report that 
it did.
reference: https://www.terraform.io/docs/providers/google/r/dns_record_set.html
*/
resource "google_dns_record_set" "spinnaker-ui" {
  # see the vars file to an explination about this count thing
  count        = length(var.cluster_config)
  name         = "${var.cluster_config[count.index]}.${var.dns_name}."
  type         = "A"
  ttl          = 300
  managed_zone = "spinnaker-wildcard-domain"
  rrdatas      = [var.ui_ip_addresses[count.index]]
}

resource "google_dns_record_set" "spinnaker-api" {
  # see the vars file to an explination about this count thing
  count        = length(var.cluster_config)
  name         = "${var.cluster_config[count.index]}-api.${var.dns_name}."
  type         = "A"
  ttl          = 300
  managed_zone = "spinnaker-wildcard-domain"
  rrdatas      = [var.api_ip_addresses[count.index]]
}

resource "google_dns_record_set" "spinnaker-api-x509" {
  # see the vars file to an explination about this count thing
  count        = length(var.cluster_config)
  name         = "${var.cluster_config[count.index]}-api-spin.${var.dns_name}."
  type         = "A"
  ttl          = 300
  managed_zone = "spinnaker-wildcard-domain"
  rrdatas      = [var.x509_ip_addresses[count.index]]
}

resource "vault_generic_secret" "spinnaker_ui_address" {
  count = length(var.cluster_config)
  path  = "secret/${var.gcp_project}/spinnaker_ui_url/${count.index}"

  data_json = <<-EOF
              {"url":"${var.cluster_config[count.index]}.${var.dns_name}"}
EOF

}

resource "vault_generic_secret" "spinnaker_api_address" {
  count = length(var.cluster_config)
  path  = "secret/${var.gcp_project}/spinnaker_api_url/${count.index}"

  data_json = <<-EOF
              {"url":"${var.cluster_config[count.index]}-api.${var.dns_name}"}
EOF

}

resource "vault_generic_secret" "spinnaker_api_x509_address" {
  count = length(var.cluster_config)
  path  = "secret/${var.gcp_project}/spinnaker_api_x509_url/${count.index}"

  data_json = <<-EOF
              {"url":"${var.cluster_config[count.index]}-api-spin.${var.dns_name}"}
EOF

}

output "spinnaker-ui_hosts" {
  value = google_dns_record_set.spinnaker-ui.*.name
}

output "spinnaker-api_hosts" {
  value = google_dns_record_set.spinnaker-api.*.name
}

output "spinnaker-api_x509_hosts" {
  value = google_dns_record_set.spinnaker-api-x509.*.name
}
