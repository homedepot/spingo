variable "terraform_account" {
  type    = string
  default = "terraform-account"
}

variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "notification_channels" {
  type        = list(string)
  description = "The list of notification channels that the policy alerts should be configured to send to SHOULD BE ADDED BY setupNotificationChannels script"
}

provider "vault" {
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]

  # credentials = file("terraform-account.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
}

data "terraform_remote_state" "np" {
  backend = "gcs"

  config = {
    bucket      = "${var.gcp_project}-tf"
    credentials = "terraform-account.json"
    prefix      = "np"
  }
}

resource "google_monitoring_uptime_check_config" "gate" {
  count        = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  display_name = "${title(data.terraform_remote_state.np.outputs.hostname_config_values[count.index])} Gate"
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
      host       = substr(data.terraform_remote_state.np.outputs.spinnaker-api_hosts[count.index], 0, length(data.terraform_remote_state.np.outputs.spinnaker-api_hosts[count.index]) - 1)
    }
  }

  selected_regions = ["USA"]

  content_matchers {
    content = "UP"
  }
}

resource "google_monitoring_alert_policy" "uptime_alert_policy" {
  count        = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  display_name = "Uptime ${title(data.terraform_remote_state.np.outputs.hostname_config_values[count.index])} Gate Policy"
  combiner     = "OR"
  conditions {
    display_name = "Uptime Health Check on ${title(data.terraform_remote_state.np.outputs.hostname_config_values[count.index])} Gate"
    condition_threshold {
      filter     = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.type=\"uptime_url\" metric.label.\"check_id\"=\"${google_monitoring_uptime_check_config.gate[count.index].uptime_check_id}\""
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
  count        = length(data.terraform_remote_state.np.outputs.cluster_config_values)
  display_name = "CloudSQL ${title(data.terraform_remote_state.np.outputs.cluster_config_values[count.index])} Queries Happening Policy"
  combiner     = "OR"
  conditions {
    display_name = "Cloud SQL Database - Queries for ${var.gcp_project}:${data.terraform_remote_state.np.outputs.google_sql_database_instance_names[count.index]} [SUM]"
    condition_threshold {
      filter     = "metric.type=\"cloudsql.googleapis.com/database/mysql/queries\" resource.type=\"cloudsql_database\" resource.label.\"database_id\"=\"${var.gcp_project}:${data.terraform_remote_state.np.outputs.google_sql_database_instance_names[count.index]}\""
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
  count        = length(data.terraform_remote_state.np.outputs.cluster_config_values)
  display_name = "Memorystore ${title(data.terraform_remote_state.np.outputs.cluster_config_values[count.index])} Redis Calls Policy"
  combiner     = "OR"
  conditions {
    display_name = "Memorystore - Calls for ${title(data.terraform_remote_state.np.outputs.cluster_config_values[count.index])} [SUM]"
    condition_threshold {
      filter     = "metric.type=\"redis.googleapis.com/commands/calls\" resource.type=\"redis_instance\" resource.label.\"instance_id\"=\"projects/${var.gcp_project}/locations/${data.terraform_remote_state.np.outputs.cluster_region}/instances/${data.terraform_remote_state.np.outputs.redis_instance_links[count.index]}\""
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
