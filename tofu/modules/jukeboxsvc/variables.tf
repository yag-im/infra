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

variable "appstor_nodes" {
  type = list(object({
    host       = string
    nfs_port   = optional(number, 2049)
    ovh_region = optional(string, "N/A")
    region     = string
    ssh_port   = optional(number, 22)
  }))
}

variable "appstor_user" {
  type = string
}

variable "jukebox_docker_repo_prefix" {
  type = string
}

variable "jukebox_nodes" {
  type = list(object({
    api_uri = string
    region  = string
  }))
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

variable "env" {
  type = string
}

# app secrets

variable "signaler_auth_token" {
  type = string
}
