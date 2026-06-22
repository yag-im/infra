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

variable "appstor_user" {
  type = string
}

variable "jukebox_docker_repo_prefix" {
  type = string
}

variable "ovh_project_id" {
  type = string
}

variable "ovh_endpoint" {
  type = string
}

variable "os_auth_url" {
  type = string
}

variable "os_identity_api_version" {
  type = string
}

variable "os_username" {
  type = string
}

variable "flask_env" {
  type = string
}

variable "signaler_host" {
  type = string
}

variable "signaler_uri" {
  type = string
}

variable "stun_uri" {
  type = string
}

variable "app_env" {
  type = string
}

# app secrets

variable "signaler_auth_token" {
  type = string
}

variable "sqldb_password" {
  type = string
}

variable "ovh_application_key" {
  type = string
}

variable "ovh_application_secret" {
  type = string
}

variable "ovh_consumer_key" {
  type = string
}

variable "os_password" {
  type = string
}
