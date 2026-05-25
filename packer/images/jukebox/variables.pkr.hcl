variable "image_name" {
  type    = string
  default = "Debian 13"
}

variable "flavor" {
  type    = string
  default = "l4-90"
}

variable "image_output_name" {
  type    = string
  # Leave empty to auto-derive from gpu_vendor (recommended).
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

# GPU vendor to install during image bake. Defaults to "nvidia" (GPU-enabled
# image). Set to "" to bake a CPU-only image.
variable "gpu_vendor" {
  type    = string
  default = "nvidia"
}
