resource "google_compute_address" "ui" {
  count  = "${length(var.cluster_config)}"
  name   = "${var.cluster_config[count.index]}-ui"
  region = "${var.cluster_region}"
}

resource "google_compute_address" "api" {
  count  = "${length(var.cluster_config)}"
  name   = "${var.cluster_config[count.index]}-api"
  region = "${var.cluster_region}"
}

# The static IP address for Halyard is being provisioned here so that the Halyard VM can be destroyed without loosing the IP which has to be added to k8s master whitelist
resource "google_compute_address" "halyard" {
  name   = "halyard-external-ip"
  region = "${var.cluster_region}"
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
  host     = "%"                                                                         # google provider as of v2.5.1 requires the host variable but only on destroy so here it is
  instance = "${google_sql_database_instance.spinnaker-mysql.*.name[count.index]}"
  password = "${random_string.spinnaker-db-service-user-password.*.result[count.index]}"
}

resource "google_sql_user" "spinnaker-migrate-user" {
  count    = "${length(var.cluster_config)}"
  name     = "orca_migrate"
  host     = "%"                                                                         # google provider as of v2.5.1 requires the host variable but only on destroy so here it is
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

resource "google_redis_instance" "cache" {
  count              = "${length(var.cluster_config)}"
  name               = "${var.cluster_config[count.index]}-ha-memory-cache"
  tier               = "STANDARD_HA"
  memory_size_gb     = 1
  redis_version      = "REDIS_3_2"
  display_name       = "${var.cluster_config[count.index]} memorystore redis cache"
  redis_configs      = "${var.redis_config}"
  authorized_network = "${element(var.authorized_networks_redis, count.index)}"
  region             = "${var.cluster_region}"
}

resource "vault_generic_secret" "halyard-ip" {
  path = "secret/${var.gcp_project}/halyard"

  data_json = <<-EOF
              {"address":"${google_compute_address.halyard.address}"}
              EOF
}

output "ui_ip_addresses" {
  value = "${google_compute_address.ui.*.address}"
}

output "api_ip_addresses" {
  value = "${google_compute_address.api.*.address}"
}

output "halyard_ip_address" {
  value = "${google_compute_address.halyard.address}"
}
