######################################################################################
# Required parameters
######################################################################################

variable "terraform_account" {
  type    = string
  default = "terraform-account"
}

variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "managed_dns_gcp_project" {
  type        = string
  description = "GCP project name where the DNS managed zone lives"
}

variable "default_node_options" {
  description = "These are the default options node options for the cluster node pool"
  type        = map(string)

  default = {
    disk_size    = 20
    disk_type    = "pd-standard"
    image        = "COS"
    machine_type = "n1-highmem-4"
    preemptible  = false
  }
}

variable "second_cluster_node_options" {
  description = "These are the default options node options for the second cluster node pool"
  type        = map(string)

  default = {
    disk_size    = 20
    disk_type    = "pd-standard"
    image        = "COS"
    machine_type = "n1-standard-1"
    preemptible  = false
  }
}

variable "default_node_pool_options" {
  type        = map(string)
  description = "Options to configure the default Node Pool created for the cluster."

  default = {
    auto_repair           = true # Whether the nodes will be automatically repaired.
    auto_upgrade          = true # Whether the nodes will be automatically upgraded.
    autoscaling_nodes_min = 1    # Minimum number of nodes to create in each zone. Must be >=1 and <= autoscaling_nodes_max.
    autoscaling_nodes_max = 3    # Maximum number of nodes to create in each zone. Must be >= autoscaling_nodes_min.
    max_pods_per_node     = 110  # The maximum number of pods per node in this node pool. Note this setting is currently in Beta: https://www.terraform.io/docs/providers/google/r/container_node_pool.html#max_pods_per_node
  }
}

variable "second_cluster_node_pool_options" {
  type        = map(string)
  description = "Options to configure the default Node Pool created for the second cluster."

  default = {
    auto_repair           = true # Whether the nodes will be automatically repaired.
    auto_upgrade          = true # Whether the nodes will be automatically upgraded.
    autoscaling_nodes_min = 1    # Minimum number of nodes to create in each zone. Must be >=1 and <= autoscaling_nodes_max.
    autoscaling_nodes_max = 10   # Maximum number of nodes to create in each zone. Must be >= autoscaling_nodes_min.
    max_pods_per_node     = 110  # The maximum number of pods per node in this node pool. Note this setting is currently in Beta: https://www.terraform.io/docs/providers/google/r/container_node_pool.html#max_pods_per_node
  }
}

variable "default_k8s_options" {
  description = "These are the default options for the cluster"
  type        = map(string)

  default = {
    binary_authorization       = false # If enabled, all container images will be validated by Google Binary Authorization.
    enable_hpa                 = true  # The status of the Horizontal Pod Autoscaling addon, which increases or decreases the number of replica pods a replication controller has based on the resource usage of the existing pods. It ensures that a Heapster pod is running in the cluster, which is also used by the Cloud Monitoring service.
    enable_vpa                 = true  # The status of the Verticaal Pod Autoscaling addon, which Vertical Pod Autoscaling automatically analyzes and (optionally) adjusts your containers' CPU requests and memory requests.
    enable_http_load_balancing = true  # The status of the HTTP (L7) load balancing controller addon, which makes it easy to set up HTTP load balancers for services in a cluster.
    enable_dashboard           = false # Whether the Kubernetes Dashboard is enabled for this cluster.
    enable_network_policy      = false # Whether we should enable the network policy addon for the master. This must be enabled in order to enable network policy for the nodes. It can only be disabled if the nodes already do not have network policies enabled.
    enable_pod_security_policy = false # Whether to enable the PodSecurityPolicy controller for this cluster. If enabled, pods must be valid under a PodSecurityPolicy to be created.
    logging_service            = "logging.googleapis.com/kubernetes"
    monitoring_service         = "monitoring.googleapis.com/kubernetes"
  }
}

variable "default_oauth_scopes" {
  description = "The default set of Google API scopes to be made available on all of the node VMs under the default service account."
  type        = list(string)

  default = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/cloud_debugger",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/trace.append",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/cloudkms",
    "https://www.googleapis.com/auth/devstorage.read_write"
  ]
}

variable "default_networks_that_can_access_k8s_api" {
  description = "A list of networks that can access the K8s API and also vault"
  type        = list(string)

  default = [
    "151.140.0.0/16",
    "165.130.0.0/16",
    "207.11.0.0/17",
    "50.207.27.182/32",
    "98.6.11.8/29",
    "50.207.28.9/32",
    "50.207.28.10/32",
    "50.207.28.11/32",
    "50.207.28.12/32",
    "50.207.28.13/32",
    "50.207.28.14/32",
    "96.83.24.232/29"
  ]
}

variable "default_node_metadata" {
  description = "The default metadata key/value pairs assigned to instances in the cluster. Used for pushing ssh keys to Nodes."
  type        = map(string)

  default = {
    disable-legacy-endpoints = "true"
  }
}

variable "default_client_certificate_config" {
  description = "description"
  type        = list

  default = [
    {
      issue_client_certificate = false
    },
  ]
}

variable "default_create_namespace" {
  description = "The default namespace in which to create spinnaker kubernetes resources"
  type        = string

  default = "spinnaker"
}


variable "cloud_dns_hostname" {
  description = "This is the hostname that cloud dns will attach to. Note that a trailing period will be added."
  type        = string
}

variable "extras" {
  type        = map(string)
  description = "Extra options to configure K8s. These are options that are unlikely to change from deployment to deployment. All options must be specified when passed as a map variable input to this module."

  default = {
    kubernetes_alpha       = false                 # Enable Kubernetes Alpha features for this cluster. When this option is enabled, the cluster cannot be upgraded and will be automatically deleted after 30 days.
    local_ssd_count        = 0                     # The amount of local SSD disks that will be attached to each cluster node.
    maintenance_start_time = "01:00"               # Time window specified for daily maintenance operations. Specify start_time in RFC3339 format "HH:MM”, where HH : [00-23] and MM : [00-59] GMT.
    metadata_config        = "GKE_METADATA_SERVER" # How to expose the node metadata to the workload running on the node. See: https://www.terraform.io/docs/providers/google/r/container_cluster.html#node_metadata
  }
  # guest_accelerator  = ""       # The accelerator type resource to expose to this instance. E.g. nvidia-tesla-k80. If unset will not attach an accelerator.
  # min_cpu_platform = "" # Minimum CPU platform to be used by this instance. The instance may be scheduled on the specified or newer CPU platform. Applicable values are the friendly names of CPU platforms, such as Intel Haswell.
}

variable "spingo_user_email" {
  description = "This is the is the email address of the person who first executed spingo for this project extracted from their gcloud login"
  type        = string
}

variable "use_local_credential_file" {
  type    = bool
  default = false
}

# Map: K8s IP ranges
###############################
variable "k8s_ip_ranges" {
  type        = map(string)
  description = "See recommended IP range sizing: https://cloud.google.com/kubernetes-engine/docs/how-to/alias-ips#defaults_limits"

  default = {
    master_cidr = "172.16.0.0/28" # Specifies a private RFC1918 block for the master's VPC. The master range must not overlap with any subnet in your cluster's VPC. The master and your cluster use VPC peering. Must be specified in CIDR notation and must be /28 subnet. See: https://www.terraform.io/docs/providers/google/r/container_cluster.html#master_ipv4_cidr_block 10.0.82.0/28
    pod_cidr    = "10.60.0.0/14"  # The IP address range of the kubernetes pods in this cluster.
    svc_cidr    = "10.190.16.0/20"
    node_cidr   = "10.190.0.0/22"
  }
}
