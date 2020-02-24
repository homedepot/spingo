provider "vault" {
}

data "vault_generic_secret" "terraform_account" {
  path = "secret/${var.gcp_project}/${var.terraform_account}"
}

provider "google" {
  credentials = var.use_local_credential_file ? file("${var.terraform_account}.json") : data.vault_generic_secret.terraform_account.data[var.gcp_project]
  project     = var.gcp_project
  zone        = var.gcp_zone
  version     = "~> 2.8"
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
    prefix      = "spingo-static-ips"
  }
}

data "vault_generic_secret" "keystore_pass" {
  path = "secret/${var.gcp_project}/keystore_pass"
}

data "vault_generic_secret" "halyard_svc_key" {
  path = data.terraform_remote_state.spinnaker.outputs.spinnaker_halyard_service_account_key_path
}

data "vault_generic_secret" "spinnaker_ui_address" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  path     = "secret/${var.gcp_project}/spinnaker_ui_url/${each.key}"
}

data "vault_generic_secret" "spinnaker_api_address" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  path     = "secret/${var.gcp_project}/spinnaker_api_url/${each.key}"
}

data "template_file" "vault" {
  template = file("./scripts/setup-vault.sh")

  vars = {
    USER = var.service_account_name
    SETUP_VAULT_CONTENTS = templatefile("./scripts/setup-vault-contents.sh", {
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        vaultYaml           = data.terraform_remote_state.spinnaker.outputs.vault_yml_files_map[k]
        clusterName         = "${k}"
        clusterRegion       = v["clusterRegion"]
        kubeConfig          = "/${var.service_account_name}/.kube/${k}.config"
        vaultBucket         = data.terraform_remote_state.spinnaker.outputs.vault_bucket_name_map[k]
        vaultKmsKey         = data.terraform_remote_state.spinnaker.outputs.vault_crypto_key_name_map[k]
        vaultAddr           = data.terraform_remote_state.spinnaker.outputs.vault_hosts_map[k]
        vaultKmsKeyRingName = data.terraform_remote_state.spinnaker.outputs.vault_keyring_name_map[v["clusterRegion"]]
        }
      }
      USER    = var.service_account_name
      DNS     = var.cloud_dns_hostname
      BUCKET  = "${var.gcp_project}${var.bucket_name}"
      PROJECT = var.gcp_project
    })
  }
}

data "template_file" "ingress" {
  template = file("./scripts/setup-ingress.sh")

  vars = {
    USER = var.service_account_name
    SETUP_INGRESS_CONTENT = templatefile("./scripts/setup-ingress-content.sh", {
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        kubeConfig     = "/${var.service_account_name}/.kube/${k}.config"
        clusterName    = "${k}"
        loadBalancerIP = data.terraform_remote_state.static_ips.outputs.api_ips_map[k]
        }
      }
      USER = var.service_account_name
      DNS  = var.cloud_dns_hostname
    })
  }
}
data "template_file" "make_update_keystore_script" {
  template = file("./scripts/make-or-update-keystore.sh")

  vars = {
    DNS             = var.cloud_dns_hostname
    KEYSTORE_PASS   = data.vault_generic_secret.keystore_pass.data["value"]
    PROJECT         = var.gcp_project != var.managed_dns_gcp_project ? var.managed_dns_gcp_project : var.gcp_project
    DNS_SA_KEY_PATH = "/${var.service_account_name}/.gcp/certbot.json"
    USER            = var.service_account_name
    CERTBOT_EMAIL   = var.certbot_email
  }
}

data "template_file" "setup_onboarding" {
  template = file("./scripts/setup-onboarding.sh")

  vars = {
    PROJECT_NAME            = var.gcp_project
    ONBOARDING_ACCOUNT      = data.terraform_remote_state.spinnaker.outputs.created_onboarding_service_account_name
    PATH_TO_ONBOARDING_KEY  = "/${var.service_account_name}/.gcp/${data.terraform_remote_state.spinnaker.outputs.created_onboarding_service_account_name}.json"
    ONBOARDING_SUBSCRIPTION = data.terraform_remote_state.spinnaker.outputs.created_onboarding_subscription_name
    USER                    = var.service_account_name
    ADMIN_GROUP             = var.spinnaker_admin_group
    HALYARD_COMMANDS = templatefile("./scripts/onboarding-halyard.sh", {
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        clientIP        = data.terraform_remote_state.static_ips.outputs.api_x509_ips_map[k]
        clientHostnames = data.terraform_remote_state.spinnaker.outputs.spinnaker_api_x509_hosts_map[k]
        kubeConfig      = "/${var.service_account_name}/.kube/${k}.config"
        }
      }
      USER        = var.service_account_name
      ADMIN_GROUP = var.spinnaker_admin_group
    })
  }
}

data "template_file" "setup-cleanup-operator" {
  template = file("./scripts/setup-cleanup-operator.sh")

  vars = {
    SETUP_CLEANUP_OPERATOR_CONTENTS = templatefile("./scripts/setup-cleanup-operator-contents.sh", {
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        kubeConfig = "/${var.service_account_name}/.kube/${k}.config"
        }
      }
    })
  }
}

data "template_file" "cert_script" {
  template = file("./scripts/x509-cert.sh")

  vars = {
    USER              = var.service_account_name
    DOMAIN            = replace(var.gcp_admin_email, "/^.*@/", "")
    DNS_DOMAIN        = var.cloud_dns_hostname
    WILDCARD_KEYSTORE = data.vault_generic_secret.keystore_pass.data["value"]
  }
}

data "template_file" "aliases" {
  template = file("./scripts/aliases.sh")

  vars = {
    USER = var.service_account_name
  }
}

data "template_file" "profile_aliases" {
  template = file("./scripts/profile-aliases.sh")

  vars = {
    USER = var.service_account_name
  }
}

data "template_file" "start_script" {
  template = file("./start.sh")

  vars = {
    GOOGLE_PROJECT          = var.gcp_project
    USER                    = var.service_account_name
    BUCKET                  = "${var.gcp_project}${var.bucket_name}"
    PROJECT                 = var.gcp_project
    SPIN_CLUSTER_ACCOUNT    = "spin_cluster_account"
    REPLACE                 = base64encode(jsonencode(data.vault_generic_secret.halyard_svc_key.data))
    SCRIPT_INGRESS          = base64encode(data.template_file.ingress.rendered)
    SCRIPT_SSL              = base64encode(data.template_file.setupSSLMultiple.rendered)
    SCRIPT_OAUTH            = base64encode(data.template_file.setupOAuthMultiple.rendered)
    SCRIPT_HALYARD          = base64encode(data.template_file.setupHalyardMultiple.rendered)
    SCRIPT_KUBERNETES       = base64encode(data.template_file.setupKubernetesMultiple.rendered)
    SCRIPT_HALPUSH          = base64encode(data.template_file.halpush.rendered)
    SCRIPT_HALGET           = base64encode(data.template_file.halget.rendered)
    SCRIPT_HALDIFF          = base64encode(data.template_file.haldiff.rendered)
    SCRIPT_ALIASES          = base64encode(data.template_file.aliases.rendered)
    SCRIPT_K8SSL            = base64encode(data.template_file.setupK8sSSlMultiple.rendered)
    SCRIPT_RESETGCP         = base64encode(data.template_file.resetgcp.rendered)
    SCRIPT_SWITCH           = base64encode(data.template_file.halswitch.rendered)
    SCRIPT_MONITORING       = base64encode(data.template_file.setupMonitoring.rendered)
    SCRIPT_SSL_KEYSTORE     = base64encode(data.template_file.make_update_keystore_script.rendered)
    SCRIPT_ONBOARDING       = base64encode(data.template_file.setup_onboarding.rendered)
    SCRIPT_X509             = base64encode(data.template_file.cert_script.rendered)
    SCRIPT_VAULT            = base64encode(data.template_file.vault.rendered)
    SCRIPT_CLEANUP_OPERATOR = base64encode(data.template_file.setup-cleanup-operator.rendered)
    SCRIPT_CREATE_FIAT      = base64encode(templatefile("./scripts/create-fiat-service-account.sh", {}))
    SCRIPT_ONBOARDING_PIPELINE = base64encode(templatefile("./scripts/onboarding-notifications-pipeline.json", {
      ONBOARDING_SUBSCRIPTION = data.terraform_remote_state.spinnaker.outputs.created_onboarding_subscription_name
      ADMIN_GROUP             = var.spinnaker_admin_group
      SLACK_ADMIN_CHANNEL     = var.spinnaker_admin_slack_channel
    }))
    SCRIPT_SPINGO_ADMIN_APP = base64encode(templatefile("./scripts/spingo-admin-application.json", {
      ADMIN_GROUP       = var.spinnaker_admin_group
      SPINGO_ADMIN_USER = var.spingo_user_email
    }))
    SCRIPT_COMMON = base64encode(templatefile("./scripts/common-functions.sh", {
      USER = var.service_account_name
    }))
    SCRIPT_SLACK = base64encode(templatefile("./scripts/setup-slack.sh", {
      TOKEN_FROM_SLACK = data.vault_generic_secret.slack_token.data["value"]
      deployments      = [for s in keys(data.terraform_remote_state.static_ips.outputs.ship_plans) : s]
    }))
    SCRIPT_QUICKSTART = base64encode(templatefile("./scripts/quickstart.sh", {
      USER = var.service_account_name
    }))
    SCRIPT_CURRENT_DEPLOYMENT = base64encode(templatefile("./scripts/configure-to-current-deployment.sh", {
      USER = var.service_account_name
    }))
    USER_SCRIPTS                  = filebase64("./scripts/user-scripts.tar")
    AUTO_START_HALYARD_QUICKSTART = var.auto_start_halyard_quickstart
    PROFILE_ALIASES               = base64encode(data.template_file.profile_aliases.rendered)
  }
}

data "template_file" "resetgcp" {
  template = file("./scripts/reset-gcp.sh")

  vars = {
    USER                 = var.service_account_name
    BUCKET               = "${var.gcp_project}${var.bucket_name}"
    PROJECT              = var.gcp_project
    SPIN_CLUSTER_ACCOUNT = "spin_cluster_account"
  }
}

data "template_file" "halpush" {
  template = file("./scripts/hal-push.sh")

  vars = {
    USER   = var.service_account_name
    BUCKET = "${var.gcp_project}${var.bucket_name}"
  }
}

data "template_file" "halget" {
  template = file("./scripts/hal-get.sh")

  vars = {
    USER   = var.service_account_name
    BUCKET = "${var.gcp_project}${var.bucket_name}"
  }
}

data "template_file" "halswitch" {
  template = file("./scripts/hal-switch.sh")

  vars = {
    USER = var.service_account_name
  }
}

data "template_file" "haldiff" {
  template = file("./scripts/hal-diff.sh")

  vars = {
    USER   = var.service_account_name
    BUCKET = "${var.gcp_project}${var.bucket_name}"
  }
}

data "template_file" "setupSSL" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  template = file("./scripts/setup-ssl.sh")

  vars = {
    USER            = var.service_account_name
    UI_URL          = "https://${data.vault_generic_secret.spinnaker_ui_address[each.key].data["url"]}"
    API_URL         = "https://${data.vault_generic_secret.spinnaker_api_address[each.key].data["url"]}"
    DNS             = var.cloud_dns_hostname
    SPIN_UI_IP      = data.google_compute_address.ui[each.key].address
    SPIN_API_IP     = data.google_compute_address.api[each.key].address
    KEYSTORE_PASS   = data.vault_generic_secret.keystore_pass.data["value"]
    KUBE_COMMANDS   = data.template_file.k8ssl[each.key].rendered
    DEPLOYMENT_NAME = each.key
  }
}

data "template_file" "k8ssl" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  template = file("./scripts/setup-k8-ssl.sh")

  vars = {
    SPIN_UI_IP  = data.google_compute_address.ui[each.key].address
    SPIN_API_IP = data.google_compute_address.api[each.key].address
    KUBE_CONFIG = "/${var.service_account_name}/.kube/${each.key}.config"
    SPIN_SERVICES = templatefile("./scripts/spin-gate-api.sh", {
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        gateSpinApiIP   = data.terraform_remote_state.static_ips.outputs.api_x509_ips_map[k]
        gateApiHostname = data.terraform_remote_state.spinnaker.outputs.spinnaker_api_hosts_map[k]
        deckHostname    = data.terraform_remote_state.spinnaker.outputs.spinnaker_ui_hosts_map[k]
        kubeConfig      = "/${var.service_account_name}/.kube/${k}.config"
        }
      }
    })
  }
}

data "template_file" "setupOAuth" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  template = file("./scripts/setup-oauth.sh")

  vars = {
    USER                = var.service_account_name
    API_URL             = "https://${data.vault_generic_secret.spinnaker_api_address[each.key].data["url"]}"
    OAUTH_CLIENT_ID     = data.vault_generic_secret.gcp_oauth.data["client-id"]
    OAUTH_CLIENT_SECRET = data.vault_generic_secret.gcp_oauth.data["client-secret"]
    DOMAIN              = replace(var.gcp_admin_email, "/^.*@/", "")
    ADMIN_EMAIL         = var.gcp_admin_email
    DEPLOYMENT_NAME     = each.key
  }
}

data "template_file" "setupHalyard" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  template = file("./scripts/setup-halyard.sh")

  vars = {
    USER                            = var.service_account_name
    ACCOUNT_PATH                    = "/${var.service_account_name}/.gcp/spinnaker-gcs-account.json"
    DOCKER                          = "docker-registry"
    ACCOUNT_NAME                    = "spin-cluster-account"
    ADMIN_GROUP                     = var.spinnaker_admin_group
    SPIN_UI_IP                      = data.google_compute_address.ui[each.key].address
    SPIN_API_IP                     = data.google_compute_address.api[each.key].address
    SPIN_REDIS_ADDR                 = data.vault_generic_secret.vault_redis[each.key].data["address"]
    DB_CONNECTION_NAME              = data.vault_generic_secret.db_address[each.key].data["address"]
    DB_SERVICE_USER_PASSWORD        = data.vault_generic_secret.orca_db_service_user_password[each.key].data["password"]
    DB_MIGRATE_USER_PASSWORD        = data.vault_generic_secret.orca_db_migrate_user_password[each.key].data["password"]
    DB_CLOUDDRIVER_SVC_PASSWORD     = data.vault_generic_secret.clouddriver_db_service_user_password[each.key].data["password"]
    DB_CLOUDDRIVER_MIGRATE_PASSWORD = data.vault_generic_secret.clouddriver_db_migrate_user_password[each.key].data["password"]
    DB_FRONT50_SVC_PASSWORD         = data.vault_generic_secret.front50_db_service_user_password[each.key].data["password"]
    DB_FRONT50_MIGRATE_PASSWORD     = data.vault_generic_secret.front50_db_migrate_user_password[each.key].data["password"]
    DEPLOYMENT_NAME                 = each.key
    DEPLOYMENT_INDEX                = index(keys(data.terraform_remote_state.static_ips.outputs.ship_plans), each.key)
    VAULT_ADDR                      = data.terraform_remote_state.spinnaker.outputs.vault_hosts_map[each.key]
    KUBE_CONFIG                     = "/${var.service_account_name}/.kube/${each.key}.config"
    SPIN_SERVICES = templatefile("./scripts/spin-gate-api.sh", {
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        gateSpinApiIP   = data.terraform_remote_state.static_ips.outputs.api_x509_ips_map[k]
        gateApiHostname = data.terraform_remote_state.spinnaker.outputs.spinnaker_api_hosts_map[k]
        deckHostname    = data.terraform_remote_state.spinnaker.outputs.spinnaker_ui_hosts_map[k]
        kubeConfig      = "/${var.service_account_name}/.kube/${k}.config"
        }
      }
    })
  }
}

data "template_file" "setupHalyardMultiple" {
  template = file("./scripts/multiple-script-template.sh")

  vars = {
    SHEBANG = "#!/bin/bash"
    SCRIPT_CONTENT = templatefile("./scripts/multiple-script-template-content.sh", {
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        script = data.template_file.setupHalyard[k].rendered
        }
      }
    })
  }
}

data "template_file" "setupKubernetesMultiple" {
  template = file("./scripts/multiple-script-template.sh")

  vars = {
    SHEBANG = "#!/bin/bash"
    SCRIPT_CONTENT = templatefile("./scripts/setup-kubernetes-dynamic.sh", {
      PROJECT             = var.gcp_project
      USER                = var.service_account_name
      ONBOARDING_SA_EMAIL = data.terraform_remote_state.spinnaker.outputs.spinnaker_onboarding_service_account_email
      VAULT_ADDR          = data.terraform_remote_state.spinnaker.outputs.vault_hosts_map
      deployments         = zipmap(concat(keys(data.terraform_remote_state.static_ips.outputs.ship_plans), formatlist("%s-agent", keys(data.terraform_remote_state.static_ips.outputs.ship_plans))), concat(values(data.terraform_remote_state.static_ips.outputs.ship_plans), values(data.terraform_remote_state.static_ips.outputs.ship_plans)))
    })
  }
}

data "template_file" "setupK8sSSlMultiple" {
  template = file("./scripts/multiple-script-template.sh")

  vars = {
    SHEBANG = "#!/bin/bash"
    SCRIPT_CONTENT = templatefile("./scripts/multiple-script-template-content.sh", {
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        script = data.template_file.k8ssl[k].rendered
        }
      }
    })
  }
}

data "template_file" "setupSSLMultiple" {
  template = file("./scripts/multiple-script-template.sh")

  vars = {
    SHEBANG = "#!/bin/bash"
    SCRIPT_CONTENT = templatefile("./scripts/multiple-script-template-content.sh", {
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        script = data.template_file.setupSSL[k].rendered
        }
      }
    })
  }
}

data "template_file" "setupOAuthMultiple" {
  template = file("./scripts/multiple-script-template.sh")

  vars = {
    SHEBANG = "#!/bin/bash"
    SCRIPT_CONTENT = templatefile("./scripts/multiple-script-template-content.sh", {
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        script = data.template_file.setupOAuth[k].rendered
        }
      }
    })
  }
}

data "template_file" "setupMonitoring" {
  template = file("./scripts/setup-monitoring.sh")

  vars = {
    SETUP_MONITORING_CONTENTS = templatefile("./scripts/setup-monitoring-content.sh", {
      USER = var.service_account_name
      DNS  = var.cloud_dns_hostname
      deployments = { for k, v in data.terraform_remote_state.static_ips.outputs.ship_plans : k => {
        metricsYaml = data.terraform_remote_state.spinnaker.outputs.metrics_yml_files_map[k]
        clusterName = v["clusterPrefix"]
        kubeConfig  = "/${var.service_account_name}/.kube/${k}.config"
        }
      }
    })
  }
}

#Get urls

data "google_compute_address" "ui" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  name     = "ui-${each.key}"
}

data "google_compute_address" "api" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  name     = "api-${each.key}"
}

data "vault_generic_secret" "vault_redis" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  path     = "secret/${var.gcp_project}/redis/${each.key}"
}

data "vault_generic_secret" "db_address" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  path     = "secret/${var.gcp_project}/db_address/${each.key}"
}

data "vault_generic_secret" "orca_db_service_user_password" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  path     = "secret/${var.gcp_project}/orca_db_service_user_password/${each.key}"
}

data "vault_generic_secret" "orca_db_migrate_user_password" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  path     = "secret/${var.gcp_project}/orca_db_migrate_user_password/${each.key}"
}

data "vault_generic_secret" "clouddriver_db_service_user_password" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  path     = "secret/${var.gcp_project}/clouddriver_db_service_user_password/${each.key}"
}

data "vault_generic_secret" "clouddriver_db_migrate_user_password" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  path     = "secret/${var.gcp_project}/clouddriver_db_migrate_user_password/${each.key}"
}

data "vault_generic_secret" "front50_db_service_user_password" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  path     = "secret/${var.gcp_project}/front50_db_service_user_password/${each.key}"
}

data "vault_generic_secret" "front50_db_migrate_user_password" {
  for_each = data.terraform_remote_state.static_ips.outputs.ship_plans
  path     = "secret/${var.gcp_project}/front50_db_migrate_user_password/${each.key}"
}

data "vault_generic_secret" "slack_token" {
  path = "secret/${var.gcp_project}/slack-token"
}

data "vault_generic_secret" "gcp_oauth" {
  path = "secret/${var.gcp_project}/gcp-oauth"
}

resource "google_compute_instance" "halyard_spin_vm" {
  name         = "halyard-thd-spinnaker"
  machine_type = "n1-standard-4"

  scheduling {
    automatic_restart = true
  }

  tags = [
    data.terraform_remote_state.spinnaker.outputs.halyard_network_name
  ]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1604-lts"
    }
  }

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    network    = data.terraform_remote_state.spinnaker.outputs.halyard_network_name
    subnetwork = data.terraform_remote_state.spinnaker.outputs.halyard_subnetwork_name

    access_config {
      nat_ip = data.terraform_remote_state.static_ips.outputs.halyard_ip
    }
  }

  metadata_startup_script = data.template_file.start_script.rendered

  service_account {
    email  = data.terraform_remote_state.spinnaker.outputs.spinnaker_halyard_service_account_email
    scopes = ["userinfo-email", "compute-rw", "storage-full", "service-control", "https://www.googleapis.com/auth/cloud-platform"]
  }
}

output "halyard_command" {
  value = "gcloud beta compute --project \"${var.gcp_project}\" ssh --tunnel-through-iap --zone \"${var.gcp_zone}\" \"${google_compute_instance.halyard_spin_vm.name}\""
}
