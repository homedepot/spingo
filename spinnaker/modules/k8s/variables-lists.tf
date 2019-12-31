# List: Networks that are authorized to access the K8s API
###############################
variable "networks_that_can_access_k8s_api" {
  type        = list(string)
  description = "A list of networks that can access the K8s API in the form of a list of CIDR blocks in string form like '10.3.20.10/32'"

  default = []
}

# List: Minimum GCP API privileges to allow to the nodes
###############################
variable "oauth_scopes" {
  type        = list(string)
  description = "The set of Google API scopes to be made available on all of the node VMs under the default service account. See: https://www.terraform.io/docs/providers/google/r/container_cluster.html#oauth_scopes"

  default = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/compute",
  ]
}

# List: Minimum roles to grant to the default Node Service Account
###############################
variable "service_account_iam_roles" {
  type        = list(string)
  description = "A list of roles to apply to the service account if one is not provided. See: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa"

  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer",
  ]
}

# List: Tags to apply to the nodes
###############################
variable "node_tags" {
  type        = list(string)
  default     = []
  description = "The list of instance tags applied to all nodes. Tags are used to identify valid sources or targets for network firewalls. If none are provided, the cluster name is used as default."
}

variable "client_certificate_config" {
  description = "Whether client certificate authorization is enabled for this cluster."
  default     = []
}

variable "cloudnat_ips" {
  type = list(string)
}
