variable "appstor" {
  type = object({
    flavor = string
    nodes = list(object({
      host       = string
      nfs_port   = optional(number, 2049)
      ovh_region = optional(string, "N/A")
      region     = string
      ssh_port   = optional(number, 22)
    }))
    public_key_path = string
    volume_size = number
  })
}

variable "k8s" {
  type = object({
    desired_nodes = number
    flavor = string
    max_nodes = number
    min_nodes = number
    ovh_region = string
  })
}

variable "networks" {
  type = list(object({
    gateway = string
    ovh_region = string
    network = string
    start = string
    end = string    
  }))
}

variable "project_id" {
  type = string
}

variable "vrack_id" {
  type = string
}
