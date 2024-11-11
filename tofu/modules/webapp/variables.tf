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

variable "app_env" {
  type = string
}

variable "ga_id" {
  type    = string
  default = ""
}
