variable "servers" {
  type = list(object({
    host       = string
    nfs_port   = optional(number, 2049)
    ovh_region = optional(string, "N/A")
    region     = string
    ssh_port   = optional(number, 22)
  }))
}
