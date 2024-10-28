# https://github.com/hashicorp/terraform-provider-kubernetes/issues/1782
variable "create_istio_vs" {
  type    = string
  default = "false"
}

# certman
variable "cert_manager_issuer_url" {
  type = string
}

variable "hostnames" {
  type = map(string)
}
