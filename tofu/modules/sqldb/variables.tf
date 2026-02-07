variable "docker_image" {
  type = string
}

variable "k8s_namespace" {
  type = string
}

variable "appsvc_user" {
  type = string
}

variable "authsvc_user" {
  type = string
}

variable "host_data_path" {
  type    = string
  default = ""
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

# secrets

variable "appsvc_password" {
  type = string
}

variable "authsvc_password" {
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

variable "postgres_work_mem" {
  type    = string
  default = "64MB"
}
