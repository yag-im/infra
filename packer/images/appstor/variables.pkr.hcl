variable "image_name" {
  type    = string
  default = "Debian 13"
}

variable "flavor" {
  type    = string
  default = "b3-8"
}

variable "image_output_name" {
  type    = string
  # Leave empty to auto-derive the default name "debian13-appstor" (recommended).
  # Override only when a custom output image name is needed.
  default = ""
}

variable "infra_env" {
  type    = string
  default = "dev"
}

variable "network" {
  type    = string
  default = "Ext-Net"
}

