variable "create_istio_vs" {
  type    = string
  default = "false"
}

variable "docker_image_pull_secrets" {
  type    = list(any)
  default = ["awsecr-cred"]
}

variable "timezone" {
  type    = string
  default = "UTC"
}
