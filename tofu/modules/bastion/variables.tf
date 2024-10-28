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

variable "env" {
  type = string
}