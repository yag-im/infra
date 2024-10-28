variable "create_istio_vs" {
  type    = string
  default = "false"
}

variable "k8s_namespace" {
  type = string
}

# app config

variable "grafana_admin_password" {
  type = string
}
