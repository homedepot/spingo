variable "terraform_account" {
  type = string
  default = "terraform-account"
}

variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

# provider "vault" {
# }

# data "vault_generic_secret" "terraform-account" {
#   path = "secret/${var.gcp_project}/${var.terraform_account}"
# }

provider "google" {
#   credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]

  credentials = file("terraform-account.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
}

data "terraform_remote_state" "vpc" {
  backend = "gcs"

  config = {
    bucket = "np-platforms-cd-thd-tf"
    credentials = "terraform-account.json"
    prefix = "np"
  }
}

resource "google_monitoring_alert_policy" "alert_policy" {
  display_name = "My Alert Policy"
  combiner = "OR"
  conditions {
    display_name = "test condition"
    condition_absent {
        duration = "180s"
        filter = "metric.type=\"redis.googleapis.com/commands/calls\" resource.type=\"redis_instance\" resource.label.\"instance_id\"=\"projects/np-platforms-cd-thd/locations/us-east1/instances/spinnaker-ha-memory-cache\""
        trigger {
            count= 1
        }
    }
    # continue from here
  }

  user_labels = {
    foo = "bar"
  }
}