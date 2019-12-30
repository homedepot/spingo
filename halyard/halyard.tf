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

variable "certbot_email" {
  description = "email account to be informed when certificates from certbot expire"
  type        = string
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
  type        = string
}

variable "spingo_user_email" {
  description = "This is the is the email address of the person who first executed spingo for this project extracted from their gcloud login"
  type        = string
}

variable "spinnaker_admin_group" {
  description = "This is the role (group) that all the Spinnaker admins are members of. Change this to whatever is the correct group for the platform operators"
  type        = string
  default     = "gg_spinnaker_admins"
}

variable "spinnaker_admin_slack_channel" {
  description = "This is the channel to be used to alert the Spinnaker platform admins that new deployment targets need to be onboarded"
  type        = string
  default     = "spinnaker_admins"
}

data "terraform_remote_state" "np" {
  backend = "gcs"

  config = {
    bucket      = "${var.gcp_project}-tf"
    credentials = "${var.terraform_account}.json"
    prefix      = "np"
  }
}

data "terraform_remote_state" "static_ips" {
  backend = "gcs"

  config = {
    bucket      = "${var.gcp_project}-tf"
    credentials = "${var.terraform_account}.json"
    prefix      = "np-static-ips"
  }
}

provider "vault" {
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

data "vault_generic_secret" "keystore-pass" {
  path = "secret/${var.gcp_project}/keystore-pass"
}

data "vault_generic_secret" "halyard-svc-key" {
  path = data.terraform_remote_state.np.outputs.spinnaker_halyard_service_account_key_path
}

data "vault_generic_secret" "spinnaker_ui_address" {
  count = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  path  = "secret/${var.gcp_project}/spinnaker_ui_url/${count.index}"
}

data "vault_generic_secret" "spinnaker_api_address" {
  count = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  path  = "secret/${var.gcp_project}/spinnaker_api_url/${count.index}"
}

data "template_file" "vault" {
  template = file("./halScripts/setupVault.sh")

  vars = {
    USER = var.service_account_name
    SETUP_VAULT_CONTENTS = templatefile("./halScripts/setup_vault_dynamic.sh", {
      deployments = zipmap(data.terraform_remote_state.np.outputs.cluster_config_values,
        [
          {
            vaultYaml           = data.terraform_remote_state.np.outputs.vault_yml_files[format("%s-%s", data.terraform_remote_state.np.outputs.cluster_config_values[0], data.terraform_remote_state.np.outputs.cluster_region)]
            clusterName         = data.terraform_remote_state.np.outputs.cluster_config_values[0]
            vaultLoadBalancerIP = data.terraform_remote_state.static_ips.outputs.vault_ips[0]
            kubeConfig          = "/${var.service_account_name}/.kube/${data.terraform_remote_state.np.outputs.cluster_config_values[0]}.config"
            vaultBucket         = format("vault_%s_%s-%s", var.gcp_project, data.terraform_remote_state.np.outputs.cluster_config_values[0], data.terraform_remote_state.np.outputs.cluster_region)
            vaultKmsKey         = data.terraform_remote_state.np.outputs.vault_crypto_key_name_map[format("%s-%s", data.terraform_remote_state.np.outputs.cluster_config_values[0], data.terraform_remote_state.np.outputs.cluster_region)]
            vaultAddr           = lookup(data.terraform_remote_state.np.outputs.vault_hosts_map, data.terraform_remote_state.np.outputs.hostname_config_values[0], "")
            }, {
            vaultYaml           = data.terraform_remote_state.np.outputs.vault_yml_files[format("%s-%s", data.terraform_remote_state.np.outputs.cluster_config_values[1], data.terraform_remote_state.np.outputs.cluster_region)]
            clusterName         = data.terraform_remote_state.np.outputs.cluster_config_values[1]
            vaultLoadBalancerIP = data.terraform_remote_state.static_ips.outputs.vault_ips[1]
            kubeConfig          = "/${var.service_account_name}/.kube/${data.terraform_remote_state.np.outputs.cluster_config_values[1]}.config"
            vaultBucket         = format("vault_%s_%s-%s", var.gcp_project, data.terraform_remote_state.np.outputs.cluster_config_values[1], data.terraform_remote_state.np.outputs.cluster_region)
            vaultKmsKey         = data.terraform_remote_state.np.outputs.vault_crypto_key_name_map[format("%s-%s", data.terraform_remote_state.np.outputs.cluster_config_values[1], data.terraform_remote_state.np.outputs.cluster_region)]
            vaultAddr           = lookup(data.terraform_remote_state.np.outputs.vault_hosts_map, data.terraform_remote_state.np.outputs.hostname_config_values[1], "")
          }
      ])
      USER           = var.service_account_name
      DNS            = var.cloud_dns_hostname
      BUCKET         = "${var.gcp_project}${var.bucket_name}"
      VAULT_KMS_RING = data.terraform_remote_state.np.outputs.vault_keyring
      CLUSTER_REGION = data.terraform_remote_state.np.outputs.cluster_region
      PROJECT        = var.gcp_project
    })
  }
}

data "template_file" "make_update_keystore_script" {
  template = file("./halScripts/make_or_update_keystore.sh")

  vars = {
    DNS           = var.cloud_dns_hostname
    KEYSTORE_PASS = data.vault_generic_secret.keystore-pass.data["value"]
    PROJECT       = var.gcp_project
    USER          = var.service_account_name
    CERTBOT_EMAIL = var.certbot_email
  }
}

data "template_file" "setup_onboarding" {
  template = file("./halScripts/setupOnboarding.sh")

  vars = {
    PROJECT_NAME            = var.gcp_project
    ONBOARDING_ACCOUNT      = data.terraform_remote_state.np.outputs.created_onboarding_service_account_name
    PATH_TO_ONBOARDING_KEY  = "/${var.service_account_name}/.gcp/${substr(data.terraform_remote_state.np.outputs.created_onboarding_service_account_name, 4, length(data.terraform_remote_state.np.outputs.created_onboarding_service_account_name) - 4)}.json"
    ONBOARDING_SUBSCRIPTION = data.terraform_remote_state.np.outputs.created_onboarding_subscription_name
    USER                    = var.service_account_name
    ADMIN_GROUP             = var.spinnaker_admin_group
    HALYARD_COMMANDS = templatefile("./halScripts/onboarding-halyard.sh", {
      deployments = zipmap(data.terraform_remote_state.np.outputs.cluster_config_values,
        [{
          clientIP        = data.terraform_remote_state.static_ips.outputs.spin_api_ips[0]
          clientHostnames = substr(data.terraform_remote_state.np.outputs.spinnaker-api_x509_hosts[0], 0, length(data.terraform_remote_state.np.outputs.spinnaker-api_x509_hosts[0]) - 1)
          kubeConfig      = "/${var.service_account_name}/.kube/${data.terraform_remote_state.np.outputs.cluster_config_values[0]}.config"
          }, {
          clientIP        = data.terraform_remote_state.static_ips.outputs.spin_api_ips[1]
          clientHostnames = substr(data.terraform_remote_state.np.outputs.spinnaker-api_x509_hosts[1], 0, length(data.terraform_remote_state.np.outputs.spinnaker-api_x509_hosts[1]) - 1)
          kubeConfig      = "/${var.service_account_name}/.kube/${data.terraform_remote_state.np.outputs.cluster_config_values[1]}.config"
      }])
      USER        = var.service_account_name
      ADMIN_GROUP = var.spinnaker_admin_group
    })
  }
}

data "template_file" "cert_script" {
  template = file("./halScripts/x509-cert.sh")

  vars = {
    USER              = var.service_account_name
    DOMAIN            = replace(var.gcp_admin_email, "/^.*@/", "")
    DNS_DOMAIN        = var.cloud_dns_hostname
    WILDCARD_KEYSTORE = data.vault_generic_secret.keystore-pass.data["value"]
  }
}

provider "google" {
  credentials = data.vault_generic_secret.terraform-account.data[var.gcp_project]
  project     = var.gcp_project
  zone        = var.gcp_zone
  version     = "~> 2.8"
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
    USER                 = var.service_account_name
    BUCKET               = "${var.gcp_project}${var.bucket_name}"
    PROJECT              = var.gcp_project
    SPIN_CLUSTER_ACCOUNT = "spin_cluster_account"
    REPLACE              = base64encode(jsonencode(data.vault_generic_secret.halyard-svc-key.data))
    SCRIPT_SSL           = base64encode(data.template_file.setupSSLMultiple.rendered)
    SCRIPT_OAUTH         = base64encode(data.template_file.setupOAuthMultiple.rendered)
    SCRIPT_HALYARD       = base64encode(data.template_file.setupHalyardMultiple.rendered)
    SCRIPT_HALPUSH       = base64encode(data.template_file.halpush.rendered)
    SCRIPT_HALGET        = base64encode(data.template_file.halget.rendered)
    SCRIPT_HALDIFF       = base64encode(data.template_file.haldiff.rendered)
    SCRIPT_ALIASES       = base64encode(data.template_file.aliases.rendered)
    SCRIPT_K8SSL         = base64encode(data.template_file.setupK8sSSlMultiple.rendered)
    SCRIPT_RESETGCP      = base64encode(data.template_file.resetgcp.rendered)
    SCRIPT_SWITCH        = base64encode(data.template_file.halswitch.rendered)
    SCRIPT_MONITORING    = base64encode(data.template_file.setupMonitoring.rendered)
    SCRIPT_SSL_KEYSTORE  = base64encode(data.template_file.make_update_keystore_script.rendered)
    SCRIPT_ONBOARDING    = base64encode(data.template_file.setup_onboarding.rendered)
    SCRIPT_X509          = base64encode(data.template_file.cert_script.rendered)
    SCRIPT_VAULT         = base64encode(data.template_file.vault.rendered)
    SCRIPT_CREATE_FIAT   = base64encode(templatefile("./halScripts/createFiatServiceAccount.sh", {}))
    SCRIPT_ONBOARDING_PIPELINE = base64encode(templatefile("./halScripts/onboardingNotificationsPipeline.json", {
      ONBOARDING_SUBSCRIPTION = data.terraform_remote_state.np.outputs.created_onboarding_subscription_name
      ADMIN_GROUP             = var.spinnaker_admin_group
      SLACK_ADMIN_CHANNEL     = var.spinnaker_admin_slack_channel
    }))
    SCRIPT_SPINGO_ADMIN_APP = base64encode(templatefile("./halScripts/spingoAdminApplication.json", {
      ADMIN_GROUP       = var.spinnaker_admin_group
      SPINGO_ADMIN_USER = var.spingo_user_email
    }))
    SCRIPT_COMMON = base64encode(templatefile("./halScripts/commonFunctions.sh", {
      USER = var.service_account_name
    }))
    SCRIPT_SLACK = base64encode(templatefile("./halScripts/setupSlack.sh", {
      TOKEN_FROM_SLACK = data.vault_generic_secret.slack-token.data["value"]
      deployments      = data.terraform_remote_state.np.outputs.cluster_config_values
    }))
    SCRIPT_QUICKSTART = base64encode(templatefile("./halScripts/quickstart.sh", {
      USER = var.service_account_name
    }))
    SCRIPT_CURRENT_DEPLOYMENT = base64encode(templatefile("./halScripts/configureToCurrentDeployment.sh", {
      USER = var.service_account_name
    }))
    PROFILE_ALIASES = base64encode(data.template_file.profile_aliases.rendered)
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
  count    = length(data.terraform_remote_state.np.outputs.cluster_config_values)
  template = file("./halScripts/setupSSL.sh")

  vars = {
    USER            = var.service_account_name
    UI_URL          = "https://${data.vault_generic_secret.spinnaker_ui_address[count.index].data["url"]}"
    API_URL         = "https://${data.vault_generic_secret.spinnaker_api_address[count.index].data["url"]}"
    DNS             = var.cloud_dns_hostname
    SPIN_UI_IP      = data.google_compute_address.ui[count.index].address
    SPIN_API_IP     = data.google_compute_address.api[count.index].address
    KEYSTORE_PASS   = data.vault_generic_secret.keystore-pass.data["value"]
    KUBE_COMMANDS   = data.template_file.k8ssl[count.index].rendered
    DEPLOYMENT_NAME = data.terraform_remote_state.np.outputs.cluster_config_values[count.index]
  }
}

data "template_file" "setupMonitoring" {
  template = file("./halScripts/setupMonitoring.sh")
}

data "template_file" "k8ssl" {
  count    = length(data.terraform_remote_state.np.outputs.cluster_config_values)
  template = file("./halScripts/setupK8SSL.sh")

  vars = {
    SPIN_UI_IP  = data.google_compute_address.ui[count.index].address
    SPIN_API_IP = data.google_compute_address.api[count.index].address
    KUBE_CONFIG = "/${var.service_account_name}/.kube/${data.terraform_remote_state.np.outputs.cluster_config_values[count.index]}.config"
    SPIN_CLI_SERVICE = templatefile("./halScripts/spin-gate-api.sh", {
      deployments = zipmap(data.terraform_remote_state.np.outputs.cluster_config_values,
        [
          {
            clientIP   = data.terraform_remote_state.static_ips.outputs.spin_api_ips[0]
            kubeConfig = "/${var.service_account_name}/.kube/${data.terraform_remote_state.np.outputs.cluster_config_values[0]}.config"
            }, {
            clientIP   = data.terraform_remote_state.static_ips.outputs.spin_api_ips[1]
            kubeConfig = "/${var.service_account_name}/.kube/${data.terraform_remote_state.np.outputs.cluster_config_values[1]}.config"
          }
      ])
    })
  }
}

data "template_file" "setupOAuth" {
  count    = length(data.terraform_remote_state.np.outputs.cluster_config_values)
  template = file("./halScripts/setupOAuth.sh")

  vars = {
    USER                = var.service_account_name
    API_URL             = "https://${data.vault_generic_secret.spinnaker_api_address[count.index].data["url"]}"
    OAUTH_CLIENT_ID     = data.vault_generic_secret.gcp-oauth.data["client-id"]
    OAUTH_CLIENT_SECRET = data.vault_generic_secret.gcp-oauth.data["client-secret"]
    DOMAIN              = replace(var.gcp_admin_email, "/^.*@/", "")
    ADMIN_EMAIL         = var.gcp_admin_email
    DEPLOYMENT_NAME     = data.terraform_remote_state.np.outputs.cluster_config_values[count.index]
  }
}

data "template_file" "setupHalyard" {
  count    = length(data.terraform_remote_state.np.outputs.cluster_config_values)
  template = file("./halScripts/setupHalyard.sh")

  vars = {
    USER                            = var.service_account_name
    ACCOUNT_PATH                    = "/${var.service_account_name}/.gcp/spinnaker-gcs-account.json"
    DOCKER                          = "docker-registry"
    ACCOUNT_NAME                    = "spin-cluster-account"
    ADMIN_GROUP                     = var.spinnaker_admin_group
    SPIN_UI_IP                      = data.google_compute_address.ui[count.index].address
    SPIN_API_IP                     = data.google_compute_address.api[count.index].address
    SPIN_REDIS_ADDR                 = data.vault_generic_secret.vault-redis[count.index].data["address"]
    DB_CONNECTION_NAME              = data.vault_generic_secret.db-address[count.index].data["address"]
    DB_SERVICE_USER_PASSWORD        = data.vault_generic_secret.db-service-user-password[count.index].data["password"]
    DB_MIGRATE_USER_PASSWORD        = data.vault_generic_secret.db-migrate-user-password[count.index].data["password"]
    DB_CLOUDDRIVER_SVC_PASSWORD     = data.vault_generic_secret.clouddriver-db-service-user-password[count.index].data["password"]
    DB_CLOUDDRIVER_MIGRATE_PASSWORD = data.vault_generic_secret.clouddriver-db-migrate-user-password[count.index].data["password"]
    DB_FRONT50_SVC_PASSWORD         = data.vault_generic_secret.front50-db-service-user-password[count.index].data["password"]
    DB_FRONT50_MIGRATE_PASSWORD     = data.vault_generic_secret.front50-db-migrate-user-password[count.index].data["password"]
    DEPLOYMENT_NAME                 = data.terraform_remote_state.np.outputs.cluster_config_values[count.index]
    DEPLOYMENT_INDEX                = count.index
    VAULT_ADDR                      = lookup(data.terraform_remote_state.np.outputs.vault_hosts_map, data.terraform_remote_state.np.outputs.hostname_config_values[count.index], "")
    KUBE_CONFIG                     = "/${var.service_account_name}/.kube/${data.terraform_remote_state.np.outputs.cluster_config_values[count.index]}.config"
  }
}

data "template_file" "setupHalyardMultiple" {
  template = file("./halScripts/multipleScriptTemplate.sh")

  vars = {
    SHEBANG = "#!/bin/bash"
    SCRIPT1 = data.template_file.setupHalyard[0].rendered
    SCRIPT2 = data.template_file.setupHalyard[1].rendered
    SCRIPT3 = ""
    SCRIPT4 = ""
    SCRIPT5 = ""
  }
}

data "template_file" "setupK8sSSlMultiple" {
  template = file("./halScripts/multipleScriptTemplate.sh")

  vars = {
    SHEBANG = "#!/bin/bash"
    SCRIPT1 = data.template_file.k8ssl[0].rendered
    SCRIPT2 = data.template_file.k8ssl[1].rendered
    SCRIPT3 = ""
    SCRIPT4 = ""
    SCRIPT5 = ""
  }
}

data "template_file" "setupSSLMultiple" {
  template = file("./halScripts/multipleScriptTemplate.sh")

  vars = {
    SHEBANG = "#!/bin/bash"
    SCRIPT1 = data.template_file.setupSSL[0].rendered
    SCRIPT2 = data.template_file.setupSSL[1].rendered
    SCRIPT3 = ""
    SCRIPT4 = ""
    SCRIPT5 = ""
  }
}

data "template_file" "setupOAuthMultiple" {
  template = file("./halScripts/multipleScriptTemplate.sh")

  vars = {
    SHEBANG = "#!/bin/bash"
    SCRIPT1 = data.template_file.setupOAuth[0].rendered
    SCRIPT2 = data.template_file.setupOAuth[1].rendered
    SCRIPT3 = ""
    SCRIPT4 = ""
    SCRIPT5 = ""
  }
}

#Get urls

data "google_compute_address" "ui" {
  count = length(data.terraform_remote_state.np.outputs.cluster_config_values)
  name  = "${data.terraform_remote_state.np.outputs.cluster_config_values[count.index]}-ui"
}

data "google_compute_address" "api" {
  count = length(data.terraform_remote_state.np.outputs.cluster_config_values)
  name  = "${data.terraform_remote_state.np.outputs.cluster_config_values[count.index]}-api"
}

data "vault_generic_secret" "vault-redis" {
  count = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  path  = "secret/${var.gcp_project}/redis/${count.index}"
}

data "vault_generic_secret" "db-address" {
  count = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  path  = "secret/${var.gcp_project}/db-address/${count.index}"
}

data "vault_generic_secret" "db-service-user-password" {
  count = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  path  = "secret/${var.gcp_project}/db-service-user-password/${count.index}"
}

data "vault_generic_secret" "db-migrate-user-password" {
  count = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  path  = "secret/${var.gcp_project}/db-migrate-user-password/${count.index}"
}

data "vault_generic_secret" "clouddriver-db-service-user-password" {
  count = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  path  = "secret/${var.gcp_project}/clouddriver-db-service-user-password/${count.index}"
}

data "vault_generic_secret" "clouddriver-db-migrate-user-password" {
  count = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  path  = "secret/${var.gcp_project}/clouddriver-db-migrate-user-password/${count.index}"
}

data "vault_generic_secret" "front50-db-service-user-password" {
  count = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  path  = "secret/${var.gcp_project}/front50-db-service-user-password/${count.index}"
}

data "vault_generic_secret" "front50-db-migrate-user-password" {
  count = length(data.terraform_remote_state.np.outputs.hostname_config_values)
  path  = "secret/${var.gcp_project}/front50-db-migrate-user-password/${count.index}"
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
    email  = data.terraform_remote_state.np.outputs.spinnaker_halyard_service_account_email
    scopes = ["userinfo-email", "compute-rw", "storage-full", "service-control", "https://www.googleapis.com/auth/cloud-platform"]
  }
}

output "halyard_command" {
  value = "gcloud beta compute --project \"${var.gcp_project}\" ssh --zone \"${var.gcp_zone}\" \"${google_compute_instance.halyard-spin-vm[0].name}\""
}
