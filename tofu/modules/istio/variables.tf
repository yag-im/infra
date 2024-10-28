# https://github.com/hashicorp/terraform-provider-kubernetes/issues/1782
variable "create_istio_vs" {
  type    = string
  default = "false"
}

variable "k8s_namespace" {
  type = string
}

variable "hostnames" {
  type = map(string)
}
