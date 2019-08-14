terraform {
  backend "gcs" {
  }
}

variable "gcp_project" {
  description = "GCP project name"
}

variable "gcp_zone" {
  description = "GCP zone to create the halyard VM in"
  type        = string
}

variable "bucket_name" {
  description = "GCP Bucket for Halyard"
  default     = "-halyard-bucket"
}

variable "service_account_name" {
  description = "spinnaker service account to run on halyard vm"
  default     = "spinnaker"
}

variable "hostname_prefix" {
  description = "hostname prefix to use for spinnaker"
  default     = "np"
}

variable "terraform_account" {
  type    = string
  default = "terraform-account"
}

variable "cloud_dns_hostname" {
  description = "This is the hostname that cloud dns will attach to. Note that a trailing period will be added."
  type        = string
}

variable "gcp_admin_email" {
  description = "This is the email of an administrator of the Google Cloud Project Organization. Possibly the one who granted the directory group read-only policy to the spinnaker-fiat service account"
  type = string
}


provider "vault" {
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

data "vault_generic_secret" "keystore-pass" {
  path = "secret/${var.gcp_project}/keystore-pass"
}

data "vault_generic_secret" "spinnaker_ui_address" {
  path = "secret/${var.gcp_project}/spinnaker_ui_url/0"
}

data "vault_generic_secret" "spinnaker_api_address" {
  path = "secret/${var.gcp_project}/spinnaker_api_url/0"
}

resource "google_service_account" "service_account" {
  display_name = var.service_account_name
  account_id   = var.service_account_name
}

resource "google_service_account_key" "svc_key" {
  service_account_id = google_service_account.service_account.name
}

resource "google_project_iam_member" "storage_admin" {
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "serviceAccountKeyAdmin" {
  role   = "roles/iam.serviceAccountKeyAdmin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "containeradmin" {
  role   = "roles/container.admin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "rolesbrowser" {
  role   = "roles/browser"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "containerclusteradmin" {
  role   = "roles/container.clusterAdmin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "serviceAccountUser" {
  role   = "roles/iam.serviceAccountUser"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

provider "google" {
  credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]
  project     = var.gcp_project
  zone        = var.gcp_zone
}

resource "google_storage_bucket_object" "service_account_key_storage" {
  name         = ".gcp/${var.service_account_name}.json"
  content      = base64decode(google_service_account_key.svc_key.private_key)
  bucket       = "${var.gcp_project}${var.bucket_name}"
  content_type = "application/json"
}

data "template_file" "aliases" {
  template = file("./halScripts/aliases.sh")

  vars = {
    USER = var.service_account_name
  }
}

data "template_file" "profile_aliases" {
  template = file("./halScripts/profile-aliases.sh")

  vars = {
    USER = var.service_account_name
  }
}

data "template_file" "start_script" {
  template = file("./start.sh")

  vars = {
    USER              = var.service_account_name
    BUCKET            = "${var.gcp_project}${var.bucket_name}"
    PROJECT           = var.gcp_project
    REPLACE           = google_service_account_key.svc_key.private_key
    SCRIPT_SSL        = base64encode(data.template_file.setupSSL.rendered)
    SCRIPT_OAUTH      = base64encode(data.template_file.setupOAuth.rendered)
    SCRIPT_SLACK      = base64encode(data.template_file.setupSlack.rendered)
    SCRIPT_HALYARD    = base64encode(data.template_file.setupHalyard.rendered)
    SCRIPT_HALPUSH    = base64encode(data.template_file.halpush.rendered)
    SCRIPT_HALGET     = base64encode(data.template_file.halget.rendered)
    SCRIPT_HALDIFF    = base64encode(data.template_file.haldiff.rendered)
    SCRIPT_ALIASES    = base64encode(data.template_file.aliases.rendered)
    SCRIPT_K8SSL      = base64encode(data.template_file.k8ssl.rendered)
    SCRIPT_RESETGCP   = base64encode(data.template_file.resetgcp.rendered)
    SCRIPT_SWITCH     = base64encode(data.template_file.halswitch.rendered)
    SCRIPT_MONITORING = base64encode(data.template_file.setupMonitoring.rendered)
    PROFILE_ALIASES   = base64encode(data.template_file.profile_aliases.rendered)

    SPIN_CLUSTER_ACCOUNT = "spin_cluster_account"
  }
}

data "template_file" "resetgcp" {
  template = file("./halScripts/resetgcp.sh")

  vars = {
    USER                 = var.service_account_name
    BUCKET               = "${var.gcp_project}${var.bucket_name}"
    PROJECT              = var.gcp_project
    SPIN_CLUSTER_ACCOUNT = "spin_cluster_account"
  }
}

data "template_file" "halpush" {
  template = file("./halScripts/halpush.sh")

  vars = {
    USER   = var.service_account_name
    BUCKET = "${var.gcp_project}${var.bucket_name}"
  }
}

data "template_file" "halget" {
  template = file("./halScripts/halget.sh")

  vars = {
    USER   = var.service_account_name
    BUCKET = "${var.gcp_project}${var.bucket_name}"
  }
}

data "template_file" "halswitch" {
  template = file("./halScripts/halswitch.sh")

  vars = {
    USER = var.service_account_name
  }
}

data "template_file" "haldiff" {
  template = file("./halScripts/haldiff.sh")

  vars = {
    USER   = var.service_account_name
    BUCKET = "${var.gcp_project}${var.bucket_name}"
  }
}

data "template_file" "setupSSL" {
  template = file("./halScripts/setupSSL.sh")

  vars = {
    USER          = var.service_account_name
    UI_URL        = "https://${data.vault_generic_secret.spinnaker_ui_address.data["url"]}"
    API_URL       = "https://${data.vault_generic_secret.spinnaker_api_address.data["url"]}"
    DNS           = var.cloud_dns_hostname
    SPIN_UI_IP    = data.google_compute_address.spinnaker-ui.address
    SPIN_API_IP   = data.google_compute_address.spinnaker-api.address
    KEYSTORE_PASS = data.vault_generic_secret.keystore-pass.data["value"]
  }
}

data "template_file" "setupMonitoring" {
  template = file("./halScripts/setupMonitoring.sh")
}

data "template_file" "k8ssl" {
  template = file("./halScripts/setupK8SSL.sh")

  vars = {
    SPIN_UI_IP  = data.google_compute_address.spinnaker-ui.address
    SPIN_API_IP = data.google_compute_address.spinnaker-api.address
  }
}

data "template_file" "setupOAuth" {
  template = file("./halScripts/setupOAuth.sh")

  vars = {
    USER                = var.service_account_name
    API_URL             = "https://${data.vault_generic_secret.spinnaker_api_address.data["url"]}"
    OAUTH_CLIENT_ID     = data.vault_generic_secret.gcp-oauth.data["client-id"]
    OAUTH_CLIENT_SECRET = data.vault_generic_secret.gcp-oauth.data["client-secret"]
    DOMAIN              = var.cloud_dns_hostname
    ADMIN_EMAIL         = var.gcp_admin_email
  }
}

data "template_file" "setupSlack" {
  template = file("./halScripts/setupSlack.sh")

  vars = {
    TOKEN_FROM_SLACK = data.vault_generic_secret.slack-token.data["value"]
  }
}

data "template_file" "setupHalyard" {
  template = file("./halScripts/setupHalyard.sh")

  vars = {
    USER                            = var.service_account_name
    ACCOUNT_PATH                    = "/${var.service_account_name}/.gcp/spinnaker-gcs-account.json"
    DOCKER                          = "docker-registry"
    ACCOUNT_NAME                    = "spin-cluster-account"
    SPIN_UI_IP                      = data.google_compute_address.spinnaker-ui.address
    SPIN_API_IP                     = data.google_compute_address.spinnaker-api.address
    SPIN_REDIS_ADDR                 = data.vault_generic_secret.vault-redis.data["address"]
    DB_CONNECTION_NAME              = data.vault_generic_secret.db-address.data["address"]
    DB_SERVICE_USER_PASSWORD        = data.vault_generic_secret.db-service-user-password.data["password"]
    DB_MIGRATE_USER_PASSWORD        = data.vault_generic_secret.db-migrate-user-password.data["password"]
    DB_CLOUDDRIVER_SVC_PASSWORD     = data.vault_generic_secret.clouddriver-db-service-user-password.data["password"]
    DB_CLOUDDRIVER_MIGRATE_PASSWORD = data.vault_generic_secret.clouddriver-db-migrate-user-password.data["password"]
  }
}

#Get urls

data "google_compute_address" "spinnaker-ui" {
  name = "spinnaker-ui"
}

data "google_compute_address" "spinnaker-api" {
  name = "spinnaker-api"
}

data "vault_generic_secret" "vault-redis" {
  path = "secret/${var.gcp_project}/redis/0"
}

data "vault_generic_secret" "db-address" {
  path = "secret/${var.gcp_project}/db-address/0"
}

data "vault_generic_secret" "db-service-user-password" {
  path = "secret/${var.gcp_project}/db-service-user-password/0"
}

data "vault_generic_secret" "db-migrate-user-password" {
  path = "secret/${var.gcp_project}/db-migrate-user-password/0"
}

data "vault_generic_secret" "clouddriver-db-service-user-password" {
  path = "secret/${var.gcp_project}/clouddriver-db-service-user-password/0"
}

data "vault_generic_secret" "clouddriver-db-migrate-user-password" {
  path = "secret/${var.gcp_project}/clouddriver-db-migrate-user-password/0"
}

data "google_compute_address" "halyard-external-ip" {
  name = "halyard-external-ip"
}

data "vault_generic_secret" "slack-token" {
  path = "secret/${var.gcp_project}/slack-token"
}

#This is manually put into vault and created manually
#Get OAUTH secrets
data "vault_generic_secret" "gcp-oauth" {
  path = "secret/${var.gcp_project}/gcp-oauth"
}

resource "google_compute_instance" "halyard-spin-vm" {
  count        = 1 // Adjust as desired
  name         = "halyard-thd-spinnaker"
  machine_type = "n1-standard-4"

  scheduling {
    automatic_restart = true
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1604-lts"
    }
  }

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = data.google_compute_address.halyard-external-ip.address
    }
  }

  metadata_startup_script = data.template_file.start_script.rendered

  service_account {
    email  = google_service_account.service_account.email
    scopes = ["userinfo-email", "compute-rw", "storage-full", "service-control", "https://www.googleapis.com/auth/cloud-platform"]
  }
}

