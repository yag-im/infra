variable "create_istio_vs" {
  type    = string
  default = "false"
}

variable "docker_image_name" {
  type = string
}

variable "docker_image_pull_secrets" {
  type    = list
  default = []
}

variable "k8s_namespace" {
  type = string
}

variable "replicas" {
  type = number
}

# app config
variable "data_centers" {
  type = list(string)
}

variable "flask_env" {
  type = string
}

variable "jukebox_container_image_rev" {
  type = string
}

variable "runners" {
  type = map(object({
    ver = string
    window_system = string,
    igpu = bool,
    dgpu = bool
  }))
}

variable "streamd_reqs" {
  type = object({
    igpu = bool
    dgpu = bool
  })
}

# app secrets

variable "sqldb_password" {
  type = string
}
