############################################
resource "google_container_cluster" "cluster" {
  count              = "${length(var.cluster_config)}"
  name               = "${var.cluster_config[count.index]}-${var.cluster_region}"
  region             = "${var.cluster_region}"
  logging_service    = "${var.logging_service}"
  monitoring_service = "${var.monitoring_service}"

  # Remove the default node pool during cluster creation.
  # We use google_container_node_pools for better control and
  # less disruptive changes.
  # https://github.com/terraform-providers/terraform-provider-google/issues/1712#issuecomment-410317055
  remove_default_node_pool = true

  #! the below is stupid but it needs to be here or the output below will fail
  master_auth {}

  node_pool {
    name = "default-pool"
  }

  lifecycle {
    ignore_changes = ["node_pool", "network"]
  }
}

# Primary node pool
resource "google_container_node_pool" "primary_pool" {
  count              = "${length(var.cluster_config)}"
  name               = "${var.cluster_config[count.index]}-${var.cluster_region}-primary-pool"
  cluster            = "${google_container_cluster.cluster.*.name[count.index]}"
  region             = "${var.cluster_region}"
  initial_node_count = 1

  autoscaling {
    min_node_count = "${var.min_node_count}"
    max_node_count = "${var.max_node_count}"
  }

  node_config {
    machine_type = "${var.machine_type}"
    oauth_scopes = ["${var.oauth_scopes}"]
  }
}

resource "google_compute_address" "ui" {
  count = "${length(var.cluster_config)}"
  name  = "${var.cluster_config[count.index]}-ui"
}

resource "google_compute_address" "api" {
  count = "${length(var.cluster_config)}"
  name  = "${var.cluster_config[count.index]}-api"
}

resource "vault_generic_secret" "vault-api" {
  count = "${length(var.cluster_config)}"
  path  = "secret/${var.gcp_project}/vault-api/${count.index}"

  data_json = <<-EOF
              {"address":"${google_compute_address.api.*.address[count.index]}"}
              EOF
}

resource "vault_generic_secret" "vault-ui" {
  count = "${length(var.cluster_config)}"
  path  = "secret/${var.gcp_project}/vault-ui/${count.index}"

  data_json = <<-EOF
              {"address":"${google_compute_address.ui.*.address[count.index]}"}
              EOF
}

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
  count        = "${length(var.cluster_config)}"
  name         = "${var.cluster_config[count.index]}.${var.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = "${var.gcp_project}"
  rrdatas      = ["${google_compute_address.ui.*.address[count.index]}"]
}

resource "google_dns_record_set" "spinnaker-api" {
  # see the vars file to an explination about this count thing
  count        = "${length(var.cluster_config)}"
  name         = "${var.cluster_config[count.index]}-api.${var.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = "${var.gcp_project}"
  rrdatas      = ["${google_compute_address.api.*.address[count.index]}"]
}

output "hosts" {
  value = "${google_container_cluster.cluster.*.endpoint}"
}

output "cluster_ca_certificates" {
  value = "${google_container_cluster.cluster.*.master_auth.0.cluster_ca_certificate}"
}

output "cluster_names" {
  value = "${values(var.cluster_config)}"
}

output "cluster_region" {
  value = "${var.cluster_region}"
}

output "cluster_config" {
  value = "${var.cluster_config}"
}
