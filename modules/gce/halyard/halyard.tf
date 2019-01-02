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
  default     = "np-platforms-cd-thd-halyard-bucket"
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

resource "google_project_iam_member" "clusterAdmin" {
  role   = "roles/container.clusterAdmin"
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
  bucket       = "${var.bucket_name}"
  content_type = "application/json"
}

data "template_file" "start_script" {
  template = "${file("${path.module}/start.sh")}"

  vars {
    #REPLACE = "${jsonencode(replace(base64decode(google_service_account_key.svc_key.private_key),"\n"," "))}"
    USER    = "${var.service_account_name}"
    BUCKET  = "${var.bucket_name}"
    REGION  = "${var.gcp_region}"
    PROJECT = "${var.gcp_project}"
    #WRITE secrets
    CLIENT_ID="${data.vault_generic_secret.gcp-oauth.data["client-id"]}"
    CLIENT_SECRET="${data.vault_generic_secret.gcp-oauth.data["client-secret"]}"
    SPIN_UI_IP="${data.vault_generic_secret.vault-ui.data["address"]}"
    SPIN_API_IP="${data.vault_generic_secret.vault-api.data["address"]}"
  }
}

#Get urls
data "vault_generic_secret" "vault-ui" {
  path = "secret/vault-ui"
}
data "vault_generic_secret" "vault-api" {
  path = "secret/vault-ui"
}

#This is manually put into vault and created manually
#Get OAUTH secrets
data "vault_generic_secret" "gcp-oauth" {
  path = "secret/gcp-oauth"
}


resource "google_compute_instance" "halyard-spin-vm-grueld" {
  count                     = 1                       // Adjust as desired
  name                      = "halyard-thd-spinnaker"
  machine_type              = "n1-standard-4"         // smallest (CPU &amp; RAM) available instance
  zone                      = "${var.gcp_region}-c"   // yields "europe-west1-d" as setup previously. Places your VM in Europe
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
