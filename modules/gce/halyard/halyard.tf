variable "gcp_region" {
  description = "GCP region, e.g. us-east1"
  default     = "us-east1"
}

variable "gcp_project" {
  description = "GCP project name"
  default     = "np-platforms-cd-thd"
}

variable "bucket_name" {
  description = "GCP Bucket for Halyard"
  default     = "-halyard-bucket"
}

variable "service_account_name" {
  description = "spinnaker service account to run on halyard vm"
  default     = "spinnaker"
}

variable vault_address {
  type    = "string"
  default = "https://vault.ioq1.homedepot.com:10231"
}

variable terraform_account {
  type    = "string"
  default = "terraform-account"
}

provider "vault" {
  address = "${var.vault_address}"
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.terraform_account}"
}

resource "google_service_account" "service_account" {
  display_name = "${var.service_account_name}"
  account_id   = "${var.service_account_name}"
}

resource "google_service_account_key" "svc_key" {
  service_account_id = "${google_service_account.service_account.name}"
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
  credentials = "${data.vault_generic_secret.terraform-account.data[var.gcp_project]}"
  project     = "${var.gcp_project}"
  region      = "${var.gcp_region}"
}

resource "google_storage_bucket_object" "service_account_key_storage" {
  name         = ".gcp/${var.service_account_name}.json"
  content      = "${base64decode(google_service_account_key.svc_key.private_key)}"
  bucket       = "${var.gcp_project}${var.bucket_name}"
  content_type = "application/json"
}

data "template_file" "aliases" {
  template = "${file("${path.module}/halScripts/aliases.sh")}"

  vars {
    USER = "${var.service_account_name}"
  }
}

data "template_file" "spingo" {
  template = "${file("${path.module}/halScripts/spingo.sh")}"

  vars {
    USER = "${var.service_account_name}"
  }
}

data "template_file" "start_script" {
  template = "${file("${path.module}/start.sh")}"

  vars {
    USER                 = "${var.service_account_name}"
    BUCKET               = "${var.gcp_project}${var.bucket_name}"
    REGION               = "${var.gcp_region}"
    PROJECT              = "${var.gcp_project}"
    REPLACE              = "${google_service_account_key.svc_key.private_key}"
    SCRIPT_SSL           = "${base64encode(data.template_file.setupSSL.rendered)}"
    SCRIPT_SAML          = "${base64encode(data.template_file.setupSAML.rendered)}"
    SCRIPT_HALYARD       = "${base64encode(data.template_file.setupHalyard.rendered)}"
    SCRIPT_HALPUSH       = "${base64encode(data.template_file.halpush.rendered)}"
    SCRIPT_HALGET        = "${base64encode(data.template_file.halget.rendered)}"
    SCRIPT_HALDIFF       = "${base64encode(data.template_file.haldiff.rendered)}"
    SCRIPT_ALIASES       = "${base64encode(data.template_file.aliases.rendered)}"
    SCRIPT_SPINGO        = "${base64encode(data.template_file.spingo.rendered)}"
    SCRIPT_K8SSL         = "${base64encode(data.template_file.k8ssl.rendered)}"
    SCRIPT_RESETGCP      = "${base64encode(data.template_file.resetgcp.rendered)}"
    SPIN_CLUSTER_ACCOUNT = "spin_cluster_account"

    #WRITE secrets
    CLIENT_ID     = "${data.vault_generic_secret.gcp-oauth.data["client-id"]}"
    CLIENT_SECRET = "${data.vault_generic_secret.gcp-oauth.data["client-secret"]}"
    SPIN_UI_IP    = "${data.vault_generic_secret.vault-ui.data["address"]}"
    SPIN_API_IP   = "${data.vault_generic_secret.vault-api.data["address"]}"
  }
}

data "template_file" "resetgcp" {
  template = "${file("${path.module}/halScripts/resetgcp.sh")}"

  vars {
    USER                 = "${var.service_account_name}"
    REGION               = "${var.gcp_region}"
    PROJECT              = "${var.gcp_project}"
    SPIN_CLUSTER_ACCOUNT = "spin_cluster_account"
  }
}

data "template_file" "halpush" {
  template = "${file("${path.module}/halScripts/halpush.sh")}"

  vars {
    USER   = "${var.service_account_name}"
    BUCKET = "${var.gcp_project}${var.bucket_name}"
  }
}

data "template_file" "halget" {
  template = "${file("${path.module}/halScripts/halget.sh")}"

  vars {
    USER   = "${var.service_account_name}"
    BUCKET = "${var.gcp_project}${var.bucket_name}"
  }
}

data "template_file" "haldiff" {
  template = "${file("${path.module}/halScripts/haldiff.sh")}"

  vars {
    USER   = "${var.service_account_name}"
    BUCKET = "${var.gcp_project}${var.bucket_name}"
  }
}

data "template_file" "setupSSL" {
  template = "${file("${path.module}/halScripts/setupSSL.sh")}"

  vars {
    USER    = "${var.service_account_name}"
    UI_URL  = "https://${var.service_account_name}.${var.gcp_project}.gcp.homedepot.com"
    API_URL = "https://${var.service_account_name}-api.${var.gcp_project}.gcp.homedepot.com"

    SPIN_UI_IP  = "${data.vault_generic_secret.vault-ui.data["address"]}"
    SPIN_API_IP = "${data.vault_generic_secret.vault-api.data["address"]}"
  }
}

data "template_file" "k8ssl" {
  template = "${file("${path.module}/halScripts/setupK8SSL.sh")}"

  vars {
    SPIN_UI_IP  = "${data.vault_generic_secret.vault-ui.data["address"]}"
    SPIN_API_IP = "${data.vault_generic_secret.vault-api.data["address"]}"
  }
}

data "template_file" "setupSAML" {
  template = "${file("${path.module}/halScripts/setupSAML.sh")}"

  vars {
    USER    = "${var.service_account_name}"
    API_URL = "https://${var.service_account_name}-api.${var.gcp_project}.gcp.homedepot.com"
  }
}

data "template_file" "setupHalyard" {
  template = "${file("${path.module}/halScripts/setupHalyard.sh")}"

  vars {
    USER         = "${var.service_account_name}"
    ACCOUNT_PATH = "/${var.service_account_name}/.gcp/spinnaker-gcs-account.json"
    DOCKER       = "docker-registry"
    ACCOUNT_NAME = "spin-cluster-account"
  }
}

#Get urls
data "vault_generic_secret" "vault-ui" {
  path = "secret/vault-ui"
}

data "vault_generic_secret" "vault-api" {
  path = "secret/vault-api"
}

#This is manually put into vault and created manually
#Get OAUTH secrets
data "vault_generic_secret" "gcp-oauth" {
  path = "secret/gcp-oauth"
}

terraform {
  backend "gcs" {
    bucket      = "np-platforms-cd-thd-tf"
    prefix      = "np-hal-vm"
    credentials = "terraform-account.json"
  }
}

resource "google_compute_instance" "halyard-spin-vm-grueld" {
  count                     = 1                       // Adjust as desired
  name                      = "halyard-thd-spinnaker"
  machine_type              = "n1-standard-4"         // smallest (CPU &amp; RAM) available instance
  zone                      = "${var.gcp_region}-c"
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1604-lts"
    }
  }

  // Local SSD disk
  scratch_disk {}

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP - leaving this block empty will generate a new external IP and assign it to the machine
    }
  }

  metadata_startup_script = "${data.template_file.start_script.rendered}"

  service_account {
    email  = "${google_service_account.service_account.email}"
    scopes = ["userinfo-email", "compute-rw", "storage-full", "service-control", "https://www.googleapis.com/auth/cloud-platform"]
  }
}
