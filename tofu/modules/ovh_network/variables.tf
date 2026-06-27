variable "project_id" {
  type = string
}

variable "vrack_id" {
  type = string
}

variable "network_name" {
  type    = string
  default = "yag-pn"
}

variable "networks" {
  type = list(object({
    gateway    = string
    ovh_region = string
    network    = string
    start      = string
    end        = string
  }))
}
