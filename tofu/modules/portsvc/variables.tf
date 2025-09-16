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

variable "flask_env" {
  type = string
}

# app secrets

variable "sqldb_password" {
  type = string
}

variable "twitch_oauth_client_id" {
  type = string
}

variable "twitch_oauth_client_secret" {
  type = string
}
