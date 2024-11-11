variable "docker_image_name" {
  type = string
}

variable "docker_image_pull_secrets" {
  type    = list(any)
  default = []
}

variable "k8s_namespace" {
  type = string
}

variable "appsvc_user" {
  type = string
}

variable "host_data_path" {
  type    = string
  default = ""
}

variable "mccsvc_user" {
  type = string
}

variable "pgdata" {
  type = string
}

# cloud providers create pv-s and define their own names
variable "pv_name" {
  type    = string
  default = ""
}

variable "portsvc_user" {
  type = string
}

variable "sessionsvc_user" {
  type = string
}

variable "storage_class_name" {
  type = string
}

variable "storage_size" {
  type = string
}

variable "timezone" {
  type = string
}

variable "yag_db" {
  type = string
}

variable "yagsvc_user" {
  type = string
}

# secrets

variable "appsvc_password" {
  type = string
}

variable "mccsvc_password" {
  type = string
}

variable "portsvc_password" {
  type = string
}

variable "postgres_password" {
  type = string
}

variable "sessionsvc_password" {
  type = string
}

variable "yagsvc_password" {
  type = string
}
