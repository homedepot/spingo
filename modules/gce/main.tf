variable "gcp_region" {
  description = "GCP region, e.g. us-east1"
  default     = "us-east1"
}

variable "gcp_project" {
  description = "GCP project name"
  default     = "np-platforms-cd-thd"
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

resource "google_project_iam_member" "storage_admin" {
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "clusterAdmin" {
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

  metadata_startup_script = <<SCRIPT
useradd spinnaker
usermod -g google-sudoers spinnaker
mkhomedir_helper spinnaker

echo "deb http://packages.cloud.google.com/apt gcsfuse-xenial main" | tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y --no-install-recommends google-cloud-sdk gcsfuse
apt-get install -y kubectl


mkdir /spinnaker
chown -R spinnaker:google-sudoers /spinnaker
chmod -R 776 /spinnaker

runuser -l spinnaker -c 'gcsfuse --dir-mode 777  np-platforms-cd-thd-halyard-bucket /spinnaker'

runuser -l spinnaker -c 'ln -s /spinnaker/.kube /home/spinnaker/.kube'
runuser -l spinnaker -c 'ln -s /spinnaker/.gcp /home/spinnaker/.gcp'

cd /home/spinnaker
runuser -l spinnaker -c 'curl -O https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh'
runuser -l spinnaker -c 'sudo bash InstallHalyard.sh -y --user spinnaker'
runuser -l spinnaker -c 'rm -rfd /home/spinnaker/.hal'
runuser -l spinnaker -c 'ln -s /spinnaker/.hal /home/spinnaker/.hal'

SCRIPT
  //metadata_startup_script = "${file("${path.module}/start.sh")}"

  service_account {
    email  = "${google_service_account.service_account.email}"
    scopes = ["userinfo-email", "compute-rw", "storage-full"]
  }
}
