# Render the YAML file
data "template_file" "vault" {
  for_each = var.ship_plans
  template = file("${path.module}/vault.yaml")

  vars = {
    vault_ui_hostname      = lookup(var.vault_hosts_map, each.key, "")
  }
}

output "vault_agent_yml_files_map" {
  value = { for k, v in var.ship_plans : k => base64encode(data.template_file.vault[k].rendered) }
}
