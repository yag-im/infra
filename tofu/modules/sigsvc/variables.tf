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

variable "debug_no_auth" {
  type    = bool
  default = false
}

# app secrets

variable "auth_token" {
  type = string
}

variable "flask_secret_key" {
  type = string
}

variable "flask_security_password_salt" {
  type = string
}
