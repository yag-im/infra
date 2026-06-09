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

variable "enable_cluster_sync_job" {
  type    = bool
  default = false
}

variable "enable_cluster_scale_job" {
  type    = bool
  default = false
}

variable "enable_sessions_trim_job" {
  type    = bool
  default = false
}
