variable "create_istio_vs" {
  type    = string
  default = "false"
}

variable "docker_image" {
  type = string
}

variable "k8s_namespace" {
  type = string
}

variable "replicas" {
  type = number
}

# app config
variable "dc_regions" {
  type = list(string)
}

variable "flask_env" {
  type = string
}

variable "runners" {
  type = map(object({
    ver           = string
    window_system = string,
    igpu          = bool,
    dgpu          = bool
    memory        = optional(number)
  }))
}

# app secrets

variable "sqldb_password" {
  type = string
}
