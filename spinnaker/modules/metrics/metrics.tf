data "vault_generic_secret" "gcp-oauth" {
  path = "secret/${var.gcp_project}/gcp-oauth"
}

# Render the YAML file
data "template_file" "values" {
  for_each = var.ship_plans
  template = file("${path.module}/metrics.yml")

  vars = {
    gf_server_root_url = "https://${var.grafana_hosts_map[each.key]}"
    gf_auth_google_client_id = data.gcp-oauth.client-id
    gf_auth_google_client_secret = data.gcp-oauth.client-secret
    gf_load_balancer_ip = var.grafana_ips_map[each.key]
  }
}
