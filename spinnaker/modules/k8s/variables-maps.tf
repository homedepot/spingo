variable "k8s_ip_ranges_map" {
  type        = map(map(string))
  description = "See recommended IP range sizing: https://cloud.google.com/kubernetes-engine/docs/how-to/alias-ips#defaults_limits"
}

# Map: K8s Control Plane Options
###############################
variable "k8s_options" {
  type        = map(string)
  description = "Extra options to configure K8s. All options must be specified when passed as a map variable input to this module."

  default = {
    binary_authorization       = false  # If enabled, all container images will be validated by Google Binary Authorization.
    enable_hpa                 = true   # The status of the Horizontal Pod Autoscaling addon, which increases or decreases the number of replica pods a replication controller has based on the resource usage of the existing pods. It ensures that a Heapster pod is running in the cluster, which is also used by the Cloud Monitoring service.
    enable_http_load_balancing = true   # The status of the HTTP (L7) load balancing controller addon, which makes it easy to set up HTTP load balancers for services in a cluster.
    enable_dashboard           = false  # Whether the Kubernetes Dashboard is enabled for this cluster.
    enable_network_policy      = false  # Whether we should enable the network policy addon for the master. This must be enabled in order to enable network policy for the nodes. It can only be disabled if the nodes already do not have network policies enabled.
    enable_pod_security_policy = false  # Whether to enable the PodSecurityPolicy controller for this cluster. If enabled, pods must be valid under a PodSecurityPolicy to be created.
    logging_service            = "none" # The logging service that the cluster should write logs to. Available options include logging.googleapis.com, logging.googleapis.com/kubernetes, and none.
    monitoring_service         = "none" # The monitoring service that the cluster should write metrics to. Automatically send metrics from pods in the cluster to the Google Cloud Monitoring API. VM metrics will be collected by Google Compute Engine regardless of this setting Available options include monitoring.googleapis.com, monitoring.googleapis.com/kubernetes, and none.
  }
}

variable "deploy" {
  default = {
    "foo" = "bar"
  }
}

# Map: K8s Node Options
###############################
variable "node_options" {
  type        = map(string)
  description = "Extra options to configure the K8s Nodes. All options must be specified when passed as a map variable input to this module."

  default = {
    disk_size    = "20"            # Size of the disk attached to each node, specified in GB. The smallest allowed disk size is 10GB.
    disk_type    = "pd-standard"   # Type of the disk attached to each node (e.g. 'pd-standard' or 'pd-ssd').
    image        = "COS"           # The image type to use for this node. Note that changing the image type will delete and recreate all nodes in the node pool. COS/UBUNTU
    machine_type = "n1-standard-1" # The name of a Google Compute Engine machine type.
    preemptible  = true            # Premptible VMs are instances that last a maximum of 24 hours and provide no availability guarantees. Preemptible VMs are priced lower than standard Compute Engine VMs and offer the same machine types and options. https://cloud.google.com/kubernetes-engine/docs/how-to/preemptible-vms
  }
}

variable "node_options_map" {
  type = map(any)
}

# Map: Node Pool options
###############################
variable "node_pool_options" {
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

variable "node_pool_options_map" {
  type = map(any)
}

# Map: Extra Options
###############################
variable "extras" {
  type        = map(string)
  description = "Extra options to configure K8s. These are options that are unlikely to change from deployment to deployment. All options must be specified when passed as a map variable input to this module."

  default = {
    kubernetes_alpha       = false    # Enable Kubernetes Alpha features for this cluster. When this option is enabled, the cluster cannot be upgraded and will be automatically deleted after 30 days.
    local_ssd_count        = 0        # The amount of local SSD disks that will be attached to each cluster node.
    maintenance_start_time = "01:00"  # Time window specified for daily maintenance operations. Specify start_time in RFC3339 format "HH:MM”, where HH : [00-23] and MM : [00-59] GMT.
    metadata_config        = "SECURE" # How to expose the node metadata to the workload running on the node. See: https://www.terraform.io/docs/providers/google/r/container_cluster.html#node_metadata
  }
  # guest_accelerator  = ""       # The accelerator type resource to expose to this instance. E.g. nvidia-tesla-k80. If unset will not attach an accelerator.
  # min_cpu_platform = "" # Minimum CPU platform to be used by this instance. The instance may be scheduled on the specified or newer CPU platform. Applicable values are the friendly names of CPU platforms, such as Intel Haswell.
}

# Map: Timeouts
###############################
variable "timeouts" {
  type        = map(string)
  description = "Configurable timeout values for the various cluster operations."

  default = {
    create = "40m" # The default timeout for a cluster create operation.
    update = "60m" # The default timeout for a cluster update operation.
    delete = "40m" # The default timeout for a cluster delete operation.
  }
}

# Map: Key-Value pairs to assign to Node metadata
###############################
variable "node_metadata" {
  type = map(string)
  default = {
  }
  description = "The metadata key/value pairs assigned to instances in the cluster. Used for pushing ssh keys to Nodes."
}

variable "ship_plans" {
  type        = map(map(string))
  description = "The object that describes all of the clusters that need to be built by Spingo"
}

variable "ship_plans_without_agent" {
  type        = map(map(string))
  description = "The object that describes all of the clusters that need to be built by Spingo"
}

variable "cloudnat_name_map" {
  type = map(string)
}

variable "crypto_key_id_map" {
  type = map(string)
}
