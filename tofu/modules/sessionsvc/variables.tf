variable "create_istio_vs" {
  type    = string
  default = "false"
}

variable "docker_image_name" {
  type = string
}

variable "docker_image_pull_secrets" {
  type    = list(any)
  default = []
}

variable "k8s_namespace" {
  type = string
}

variable "replicas" {
  type = number
}

# app config

variable "flask_env" {
  type = string
}

# app secrets

variable "sqldb_password" {
  type = string
}
