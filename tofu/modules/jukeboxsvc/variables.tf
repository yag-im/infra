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

variable "aws_ecr_host" {
  type = string
}

variable "aws_ecr_region" {
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

# app secrets

variable "aws_ecr_access_key" {
  type = string
}

variable "aws_ecr_secret_key" {
  type = string
}

variable "signaler_auth_token" {
  type = string
}
