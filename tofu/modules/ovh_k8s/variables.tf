variable "project_id" {
  type = string
}

variable "k8s" {
  type = object({
    desired_nodes = number
    flavor        = string
    max_nodes     = number
    min_nodes     = number
    ovh_region    = string
  })
}

variable "private_network_regions_attributes" {
  description = "regions_attributes from the OVH private network resource"
  type        = any
}

variable "private_subnets" {
  description = "Per-region subnet info from ovh_network module"
  type = list(object({
    id         = string
    ovh_region = string
    gateway    = string
  }))
}

variable "network_ready" {
  description = "Synchronization handle from ovh_network module"
  type        = any
  default     = null
}

variable "kubeconfig_filename" {
  description = "Output filename for the kubeconfig file"
  type        = string
  default     = "kubeconfig"
}
