provider "vault" {
}

data "vault_generic_secret" "terraform_account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = data.vault_generic_secret.terraform_account.data[var.gcp_project]

  # credentials = file("${var.terraform_account}.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
}

data "terraform_remote_state" "spinnaker" {
  backend = "gcs"

  config = {
    bucket      = "${var.gcp_project}-tf"
    credentials = "${var.terraform_account}.json" # this has to be a direct file location because it is needed before interpolation
    prefix      = "spingo-spinnaker"
  }
}

data "terraform_remote_state" "static_ips" {
  backend = "gcs"

  config = {
    bucket      = "${var.gcp_project}-tf"
    credentials = "${var.terraform_account}.json" # this has to be a direct file location because it is needed before interpolation
    prefix      = "spingo-static_ips"
  }
}

resource "google_monitoring_uptime_check_config" "gate" {
  for_each     = data.terraform_remote_state.static_ips.outputs.ship_plans
  display_name = "${title(each.value["gateSubdomain"])} Gate"
  timeout      = "60s"

  http_check {
    use_ssl = true
    path    = "/health"
    port    = "443"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.gcp_project
      host       = data.terraform_remote_state.spinnaker.outputs.spinnaker_api_hosts_map[each.key]
    }
  }

  selected_regions = ["USA"]

  content_matchers {
    content = "UP"
  }
}

resource "google_monitoring_alert_policy" "uptime_alert_policy" {
  for_each     = data.terraform_remote_state.static_ips.outputs.ship_plans
  display_name = "Uptime ${title(each.value["gateSubdomain"])} Gate Policy"
  combiner     = "OR"
  conditions {
    display_name = "Uptime Health Check on ${title(each.value["gateSubdomain"])} Gate"
    condition_threshold {
      filter     = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.type=\"uptime_url\" metric.label.\"check_id\"=\"${google_monitoring_uptime_check_config.gate[each.key].uptime_check_id}\""
      comparison = "COMPARISON_GT"
      duration   = "60s"
      trigger {
        count = 1
      }
      threshold_value = 1
      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.*"]
      }
    }
  }

  notification_channels = var.notification_channels

  user_labels = {
    created_by = "terraform"
  }
}

resource "google_monitoring_alert_policy" "cloudsql_alert_policy" {
  for_each     = data.terraform_remote_state.static_ips.outputs.ship_plans
  display_name = "CloudSQL ${title(each.value["clusterPrefix"])} Queries Happening Policy"
  combiner     = "OR"
  conditions {
    display_name = "Cloud SQL Database - Queries for ${var.gcp_project}:${data.terraform_remote_state.spinnaker.outputs.google_sql_database_instance_names_map[each.key]} [SUM]"
    condition_threshold {
      filter     = "metric.type=\"cloudsql.googleapis.com/database/mysql/queries\" resource.type=\"cloudsql_database\" resource.label.\"database_id\"=\"${var.gcp_project}:${data.terraform_remote_state.spinnaker.outputs.google_sql_database_instance_names_map[each.key]}\""
      comparison = "COMPARISON_LT"
      duration   = "180s"
      trigger {
        count = 1
      }
      threshold_value = 20
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = var.notification_channels

  user_labels = {
    created_by = "terraform"
  }
}

resource "google_monitoring_alert_policy" "memorystore_alert_policy" {
  for_each     = data.terraform_remote_state.static_ips.outputs.ship_plans
  display_name = "Memorystore ${title(each.value["clusterPrefix"])} Redis Calls Policy"
  combiner     = "OR"
  conditions {
    display_name = "Memorystore - Calls for ${title(each.value["clusterPrefix"])} [SUM]"
    condition_threshold {
      filter     = "metric.type=\"redis.googleapis.com/commands/calls\" resource.type=\"redis_instance\" resource.label.\"instance_id\"=\"projects/${var.gcp_project}/locations/${each.value["clusterRegion"]}/instances/${data.terraform_remote_state.spinnaker.outputs.redis_instance_links_map[each.key]}\""
      comparison = "COMPARISON_LT"
      duration   = "180s"
      trigger {
        count = 1
      }
      threshold_value = 200
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = var.notification_channels

  user_labels = {
    created_by = "terraform"
  }
}

resource "google_monitoring_alert_policy" "cloudsql_failover_replica_lag_alert_policy" {
  for_each     = data.terraform_remote_state.static_ips.outputs.ship_plans
  display_name = "CloudSQL ${title(each.value["clusterPrefix"])} Failover Replica Lag Policy"
  combiner     = "OR"
  conditions {
    display_name = "Cloud SQL Database - Replica Lag for ${var.gcp_project}:${data.terraform_remote_state.spinnaker.outputs.google_sql_database_instance_names_map[each.key]}"
    condition_threshold {
      filter     = "metric.type=\"cloudsql.googleapis.com/database/mysql/replication/seconds_behind_master\" resource.type=\"cloudsql_database\" resource.label.\"database_id\"=\"${var.gcp_project}:${data.terraform_remote_state.spinnaker.outputs.google_sql_database_failover_instance_names_map[each.key]}\""
      comparison = "COMPARISON_GT"
      duration   = "60s"
      trigger {
        count = 1
      }
      threshold_value = 60
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.database_id"]
      }
    }
  }

  notification_channels = var.notification_channels

  user_labels = {
    created_by = "terraform"
  }
}
