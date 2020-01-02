resource "google_sql_database_instance" "cloudsql" {
  for_each         = var.ship_plans
  name             = "${each.value["clusterPrefix"]}-${random_string.db_name[each.key].result}-mysql"
  database_version = "MYSQL_5_7"
  region           = each.value["clusterRegion"]

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    # We are taking a guess at this machine type for productionizing spinnaker
    #   There isn't any info that we could find on the internet suggesting an
    #   appropriate size to use.  The db-n1-standard-2 is a 2-core 7GB memory 
    #   machine type
    tier = var.cloudsql_machine_type

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

resource "google_sql_database_instance" "cloudsql_failover" {
  for_each             = var.ship_plans
  name                 = "${each.value["clusterPrefix"]}-${random_string.db_name[each.key].result}-mysql-failover"
  region               = each.value["clusterRegion"]
  database_version     = "MYSQL_5_7"
  master_instance_name = google_sql_database_instance.cloudsql[each.key].name

  replica_configuration {
    failover_target = "true"
  }

  settings {
    tier = var.cloudsql_machine_type
    # Nota Bene: This flag is not currently possible to set, as it is not
    # listed in the 'approved' flags here: https://cloud.google.com/sql/docs/mysql/flags
    # database_flags {
    #   name  = "transaction_isolation"
    #   value = "READ-COMMITTED"
    # }
  }
}

resource "google_sql_database" "orca" {
  for_each  = var.ship_plans
  name      = "orca"
  instance  = google_sql_database_instance.cloudsql[each.key].name
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

resource "google_sql_database" "clouddriver" {
  for_each  = var.ship_plans
  name      = "clouddriver"
  instance  = google_sql_database_instance.cloudsql[each.key].name
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

resource "google_sql_database" "front50" {
  for_each  = var.ship_plans
  name      = "front50"
  instance  = google_sql_database_instance.cloudsql[each.key].name
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

resource "google_sql_user" "orca_service_user" {
  for_each = var.ship_plans
  name     = "orca_service"
  host     = "%" # google provider as of v2.5.1 requires the host variable but only on destroy so here it is
  instance = google_sql_database_instance.cloudsql[each.key].name
  password = random_string.orca_db_service_user_password[each.key].result
}

resource "google_sql_user" "clouddriver_service_user" {
  for_each = var.ship_plans
  name     = "clouddriver_service"
  host     = "%" # google provider as of v2.5.1 requires the host variable but only on destroy so here it is
  instance = google_sql_database_instance.cloudsql[each.key].name
  password = random_string.clouddriver_db_service_user_password[each.key].result
}


resource "google_sql_user" "front50_service_user" {
  for_each = var.ship_plans
  name     = "front50_service"
  host     = "%" # google provider as of v2.5.1 requires the host variable but only on destroy so here it is
  instance = google_sql_database_instance.cloudsql[each.key].name
  password = random_string.front50_db_service_user_password[each.key].result
}

resource "google_sql_user" "orca_migrate_user" {
  for_each = var.ship_plans
  name     = "orca_migrate"
  host     = "%" # google provider as of v2.5.1 requires the host variable but only on destroy so here it is
  instance = google_sql_database_instance.cloudsql[each.key].name
  password = random_string.orca_db_migrate_user_password[each.key].result
}

resource "google_sql_user" "clouddriver_migrate_user" {
  for_each = var.ship_plans
  name     = "clouddriver_migrate"
  host     = "%" # google provider as of v2.5.1 requires the host variable but only on destroy so here it is
  instance = google_sql_database_instance.cloudsql[each.key].name
  password = random_string.clouddriver_db_migrate_user_password[each.key].result
}


resource "google_sql_user" "front50_migrate_user" {
  for_each = var.ship_plans
  name     = "front50_migrate"
  host     = "%" # google provider as of v2.5.1 requires the host variable but only on destroy so here it is
  instance = google_sql_database_instance.cloudsql[each.key].name
  password = random_string.front50_db_migrate_user_password[each.key].result
}

resource "random_string" "orca_db_service_user_password" {
  for_each = var.ship_plans
  length   = 12
  special  = false
}

resource "random_string" "orca_db_migrate_user_password" {
  for_each = var.ship_plans
  length   = 12
  special  = false
}

resource "random_string" "clouddriver_db_service_user_password" {
  for_each = var.ship_plans
  length   = 12
  special  = false
}

resource "random_string" "clouddriver_db_migrate_user_password" {
  for_each = var.ship_plans
  length   = 12
  special  = false
}

resource "random_string" "front50_db_service_user_password" {
  for_each = var.ship_plans
  length   = 12
  special  = false
}

resource "random_string" "front50_db_migrate_user_password" {
  for_each = var.ship_plans
  length   = 12
  special  = false
}

resource "random_string" "db_name" {
  for_each = var.ship_plans
  length   = 4
  special  = false
  upper    = false
}

resource "google_redis_instance" "cache" {
  for_each           = var.ship_plans
  name               = "${each.value["clusterPrefix"]}-ha-memory-cache"
  tier               = "STANDARD_HA"
  memory_size_gb     = 1
  redis_version      = "REDIS_4_0"
  display_name       = "${each.value["clusterPrefix"]} memorystore redis cache"
  redis_configs      = var.redis_config
  authorized_network = var.authorized_networks_redis[each.key]
  region             = each.value["clusterRegion"]
}

resource "vault_generic_secret" "redis_connection" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/redis/${each.key}"

  data_json = <<-EOF
              {"address":"${google_redis_instance.cache[each.key].host}:${google_redis_instance.cache[each.key].port}"}
EOF

}

resource "vault_generic_secret" "orca_db_service_user_password" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/orca_db_service_user_password/${each.key}"

  data_json = <<-EOF
              {"password":"${random_string.orca_db_service_user_password[each.key].result}"}
EOF

}

resource "vault_generic_secret" "orca_db_migrate_user_password" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/orca_db_migrate_user_password/${each.key}"

  data_json = <<-EOF
              {"password":"${random_string.orca_db_migrate_user_password[each.key].result}"}
EOF

}

resource "vault_generic_secret" "clouddriver_db_service_user_password" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/clouddriver_db_service_user_password/${each.key}"

  data_json = <<-EOF
              {"password":"${random_string.clouddriver_db_service_user_password[each.key].result}"}
EOF

}

resource "vault_generic_secret" "clouddriver_db_migrate_user_password" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/clouddriver_db_migrate_user_password/${each.key}"

  data_json = <<-EOF
              {"password":"${random_string.clouddriver_db_migrate_user_password[each.key].result}"}
EOF

}

resource "vault_generic_secret" "front50_db_service_user_password" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/front50_db_service_user_password/${each.key}"

  data_json = <<-EOF
              {"password":"${random_string.front50_db_service_user_password[each.key].result}"}
EOF

}

resource "vault_generic_secret" "front50_db_migrate_user_password" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/front50_db_migrate_user_password/${each.key}"

  data_json = <<-EOF
              {"password":"${random_string.front50_db_migrate_user_password[each.key].result}"}
EOF

}
resource "vault_generic_secret" "db_address" {
  for_each = var.ship_plans
  path     = "secret/${var.gcp_project}/db_address/${each.key}"

  data_json = <<-EOF
              {"address":"${google_sql_database_instance.cloudsql[each.key].connection_name}"}
EOF

}

output "redis_instance_link_map" {
  value = { for k, v in var.ship_plans : k => google_redis_instance.cache[k].name }
}

output "google_sql_database_instance_names_map" {
  value = { for k, v in var.ship_plans : k => google_sql_database_instance.cloudsql[k].name }
}

output "google_sql_database_failover_instance_names_map" {
  value = { for k, v in var.ship_plans : k => google_sql_database_instance.cloudsql_failover[k].name }
}
