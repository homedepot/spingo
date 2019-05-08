terraform {
  backend "gcs" {
  }
}

variable "gcp_project" {
  description = "GCP project name"
  type        = string
}

variable "gcp_zone" {
  description = "GCP zone to create the certbot VM in"
  type        = string
}

variable "service_account_name" {
  default = "certbot"
  type    = string
}

variable "wildcard_dns_name" {
  description = "This is the name of the dns wildcard domain"
  type        = string
}

variable "bucket_name" {
  type = string
}

resource "google_storage_bucket_object" "service_account_key_storage" {
  name         = ".gcp/${var.service_account_name}.json"
  content      = base64decode(google_service_account_key.svc_key.private_key)
  bucket       = var.bucket_name
  content_type = "application/json"
}

variable "terraform_account" {
  type = string
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

data "vault_generic_secret" "keystore-pass" {
  path = "secret/${var.gcp_project}/keystore-pass"
}

resource "google_service_account" "service_account" {
  display_name = var.service_account_name
  account_id   = var.service_account_name
}

resource "google_service_account_key" "svc_key" {
  service_account_id = google_service_account.service_account.name
}

resource "google_project_iam_member" "dns-admin" {
  role   = "roles/dns.admin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "storage_admin" {
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

//roles/storage.objectAdmin
resource "google_project_iam_member" "objectAdmin" {
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "rolesviewer" {
  role   = "roles/viewer"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "roleseditor" {
  role   = "roles/editor"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "rolesbrowser" {
  role   = "roles/browser"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

provider "google" {
  credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]

  # credentials = file("${path.module}/terraform-account.json") //! swtich to this if you need to import stuff from GCP
  project = var.gcp_project
  zone    = var.gcp_zone
}

data "template_file" "start_script" {
  template = file("${path.module}/initCertBot.sh")

  vars = {
    # Allows us to push the key without checking it in or putting it in the storage bucketcd
    REPLACE = jsonencode(
      replace(
        base64decode(google_service_account_key.svc_key.private_key),
        "\n",
        " ",
      ),
    )
    USER                        = var.service_account_name
    BUCKET                      = var.bucket_name
    PROJECT                     = var.gcp_project
    DNS                         = var.wildcard_dns_name
    LINKER_SCRIPT               = base64encode(data.template_file.linker_script.rendered)
    MAKE_UPDATE_KEYSTORE_SCRIPT = base64encode(data.template_file.make_update_keystore_script.rendered)
    PROFILE_ALIASES             = base64encode(data.template_file.profile_aliases.rendered)
    USER_ALIASES                = base64encode(data.template_file.user_aliases.rendered)
  }
}

data "template_file" "linker_script" {
  template = file("${path.module}/symlinker.sh")
}

data "template_file" "make_update_keystore_script" {
  template = file("${path.module}/make_or_update_keystore.sh")

  vars = {
    DNS           = var.wildcard_dns_name
    KEYSTORE_PASS = data.vault_generic_secret.keystore-pass.data["value"]
  }
}

data "template_file" "profile_aliases" {
  template = file("${path.module}/profile-aliases.sh")

  vars = {
    USER   = var.service_account_name
    BUCKET = var.bucket_name
  }
}

data "template_file" "user_aliases" {
  template = file("${path.module}/user-aliases.sh")

  vars = {
    USER   = var.service_account_name
    BUCKET = var.bucket_name
  }
}

resource "google_compute_instance" "certbot-spinnaker" {
  count                     = 1 // Adjust as desired
  name                      = "certbot-spinnaker"
  machine_type              = "n1-standard-4" // smallest (CPU &amp; RAM) available instance
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  tags = ["certbot"]

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP - leaving this block empty will generate a new external IP and assign it to the machine
    }
  }

  metadata_startup_script = data.template_file.start_script.rendered

  service_account {
    email  = google_service_account.service_account.email
    scopes = ["userinfo-email", "compute-rw", "storage-full", "service-control", "https://www.googleapis.com/auth/cloud-platform"]
  }
}

