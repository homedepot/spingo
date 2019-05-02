######################################################################################
# Required parameters
######################################################################################

variable terraform_account {
  type = "string"
}

variable "cluster_region" {
  type        = "string"
  description = "GCP region, e.g. us-east1"
}

variable "gcp_project" {
  description = "GCP project name"
}

variable "managed_dns_gcp_project" {
  description = "GCP project name where the DNS managed zone lives"
}

variable "cloud_dns_hostname" {
  description = "This is the hostname that cloud dns will attach to. Note that a trailing period will be added."
}

variable "default_node_options" {
  description = "These are the default options node options for the cluster node pool"
  type        = "map"

  default = {
    disk_size    = 20
    disk_type    = "pd-standard"
    image        = "COS"
    machine_type = "n1-standard-4"
    preemptible  = false
  }
}

variable "default_k8s_options" {
  description = "These are the default options for the cluster"
  type        = "map"

  default = {
    binary_authorization       = false                                  # If enabled, all container images will be validated by Google Binary Authorization.
    enable_hpa                 = true                                   # The status of the Horizontal Pod Autoscaling addon, which increases or decreases the number of replica pods a replication controller has based on the resource usage of the existing pods. It ensures that a Heapster pod is running in the cluster, which is also used by the Cloud Monitoring service.
    enable_http_load_balancing = true                                   # The status of the HTTP (L7) load balancing controller addon, which makes it easy to set up HTTP load balancers for services in a cluster.
    enable_dashboard           = false                                  # Whether the Kubernetes Dashboard is enabled for this cluster.
    enable_network_policy      = false                                  # Whether we should enable the network policy addon for the master. This must be enabled in order to enable network policy for the nodes. It can only be disabled if the nodes already do not have network policies enabled.
    enable_pod_security_policy = false                                  # Whether to enable the PodSecurityPolicy controller for this cluster. If enabled, pods must be valid under a PodSecurityPolicy to be created.
    logging_service            = "logging.googleapis.com/kubernetes"
    monitoring_service         = "monitoring.googleapis.com/kubernetes"
  }
}

variable "default_oauth_scopes" {
  description = "The default set of Google API scopes to be made available on all of the node VMs under the default service account."
  type        = "list"

  default = [
    "https://www.googleapis.com/auth/cloud_debugger",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/trace.append",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

variable "default_networks_that_can_access_k8s_api" {
  description = "A list of networks that can access the K8s API"
  type        = "list"

  default = [{
    cidr_blocks = [{
      cidr_block = "151.140.0.0/16"
    },
      {
        cidr_block = "165.130.0.0/16"
      },
      {
        cidr_block = "207.11.0.0/17"
      },
      {
        cidr_block = "50.207.27.182/32"
      },
      {
        cidr_block = "98.6.11.8/29"
      },
      {
        cidr_block = "50.207.28.9/32"
      },
      {
        cidr_block = "50.207.28.10/32"
      },
      {
        cidr_block = "50.207.28.11/32"
      },
      {
        cidr_block = "50.207.28.12/32"
      },
      {
        cidr_block = "50.207.28.13/32"
      },
      {
        cidr_block = "50.207.28.14/32"
      },
      {
        cidr_block = "35.237.189.247/32" # hard coded halyard vm external ip until terraform v0.12
      },
      {
        cidr_block = "35.227.120.4/32" # hard coded spinnaker cloud nat value until terraform v0.12
      },
      {
        cidr_block = "35.227.117.42/32" # hard coded sandbox cloud nat value until terraform v0.12
      },
    ]
  }]
}

variable "default_node_metadata" {
  description = "The default metadata key/value pairs assigned to instances in the cluster. Used for pushing ssh keys to Nodes."
  type        = "map"

  default = {
    disable-legacy-endpoints = "true"
  }
}

variable "default_client_certificate_config" {
  description = "description"
  type        = "list"

  default = [{
    issue_client_certificate = false
  }]
}
