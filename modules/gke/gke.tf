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

  ip_allocation_policy {
    use_ip_aliases = true
  }

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

resource "vault_generic_secret" "redis-connection" {
  count = "${length(var.cluster_config)}"
  path  = "secret/${var.gcp_project}/redis/${count.index}"

  data_json = <<-EOF
              {"address":"${google_redis_instance.cache.*.host[count.index]}:${google_redis_instance.cache.*.port[count.index]}"}
              EOF
}

resource "vault_generic_secret" "spinnaker-db-service-user-password" {
  count = "${length(var.cluster_config)}"
  path  = "secret/${var.gcp_project}/db-service-user-password/${count.index}"

  data_json = <<-EOF
              {"password":"${random_string.spinnaker-db-service-user-password.*.result[count.index]}"}
              EOF
}

resource "vault_generic_secret" "spinnaker-db-migrate-user-password" {
  count = "${length(var.cluster_config)}"
  path  = "secret/${var.gcp_project}/db-migrate-user-password/${count.index}"

  data_json = <<-EOF
              {"password":"${random_string.spinnaker-db-migrate-user-password.*.result[count.index]}"}
              EOF
}

resource "vault_generic_secret" "spinnaker-db-address" {
  count = "${length(var.cluster_config)}"
  path  = "secret/${var.gcp_project}/db-address/${count.index}"

  data_json = <<-EOF
              {"address":"${google_sql_database_instance.spinnaker-mysql.*.connection_name[count.index]}"}
              EOF
}

resource "google_sql_database_instance" "spinnaker-mysql" {
  count            = "${length(var.cluster_config)}"
  name             = "${var.cluster_config[count.index]}-${random_string.spinnaker-db-name.*.result[count.index]}-mysql"
  database_version = "MYSQL_5_7"
  region           = "${var.cluster_region}"

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    # We are taking a guess at this machine type for productionizing spinnaker
    #   There isn't any info that we could find on the internet suggesting an
    #   appropriate size to use.  The db-n1-standard-2 is a 2-core 7GB memory 
    #   machine type
    tier = "${var.cloudsql_machine_type}"

    backup_configuration {
      binary_log_enabled = "true"
      enabled            = "true"
    }

    # Nota Bene: This flag is not currently possible to set, as it is not
    # listed in the 'approved' flags here: https://cloud.google.com/sql/docs/mysql/flags
    # database_flags {
    #   name  = "transaction_isolation"
    #   value = "READ-COMMITTED"
    # }
  }
}

resource "google_sql_database_instance" "spinnaker-mysql-failover" {
  count                = "${length(var.cluster_config)}"
  name                 = "${var.cluster_config[count.index]}-${random_string.spinnaker-db-name.*.result[count.index]}-mysql-failover"
  region               = "${var.cluster_region}"
  database_version     = "MYSQL_5_7"
  master_instance_name = "${google_sql_database_instance.spinnaker-mysql.*.name[count.index]}"

  replica_configuration {
    failover_target = "true"
  }

  settings {
    tier = "${var.cloudsql_machine_type}"

    # Nota Bene: This flag is not currently possible to set, as it is not
    # listed in the 'approved' flags here: https://cloud.google.com/sql/docs/mysql/flags
    # database_flags {
    #   name  = "transaction_isolation"
    #   value = "READ-COMMITTED"
    # }
  }
}

resource "google_sql_database" "orca" {
  count     = "${length(var.cluster_config)}"
  name      = "orca"
  instance  = "${google_sql_database_instance.spinnaker-mysql.*.name[count.index]}"
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

resource "google_sql_user" "spinnaker-service-user" {
  count    = "${length(var.cluster_config)}"
  name     = "orca_service"
  instance = "${google_sql_database_instance.spinnaker-mysql.*.name[count.index]}"
  password = "${random_string.spinnaker-db-service-user-password.*.result[count.index]}"
}

resource "google_sql_user" "spinnaker-migrate-user" {
  count    = "${length(var.cluster_config)}"
  name     = "orca_migrate"
  instance = "${google_sql_database_instance.spinnaker-mysql.*.name[count.index]}"
  password = "${random_string.spinnaker-db-migrate-user-password.*.result[count.index]}"
}

resource "random_string" "spinnaker-db-service-user-password" {
  count   = "${length(var.cluster_config)}"
  length  = 12
  special = false
}

resource "random_string" "spinnaker-db-migrate-user-password" {
  count   = "${length(var.cluster_config)}"
  length  = 12
  special = false
}

resource "random_string" "spinnaker-db-name" {
  count   = "${length(var.cluster_config)}"
  length  = 4
  special = false
  upper   = false
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

resource "google_redis_instance" "cache" {
  count          = "${length(var.cluster_config)}"
  name           = "${var.cluster_config[count.index]}-ha-memory-cache"
  tier           = "STANDARD_HA"
  memory_size_gb = 1
  redis_version  = "REDIS_3_2"
  display_name   = "${var.cluster_config[count.index]} memorystore redis cache"
  redis_configs  = "${var.redis_config}"
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
