variable "jukebox_nodes" {
  description = "Per-region jukebox VM definitions for Kubernetes external service/endpoint mapping"
  type = list(object({
    region         = string
    base_ip_prefix = string
    count          = optional(number, 10)
    base_ip_octet  = optional(number, 2)
    docker_port    = optional(number, 2375)
    ssh_port       = optional(number, 22)
  }))
  default = []
}

variable "appstor_nodes" {
  description = "Per-region appstor VM definitions for Kubernetes external service/endpoint mapping"
  type = list(object({
    region         = string
    base_ip_prefix = string
    count          = optional(number, 2)
    base_ip_octet  = optional(number, 200)
    ssh_port       = optional(number, 22)
    nfs_port       = optional(number, 2049)
  }))
  default = []
}

