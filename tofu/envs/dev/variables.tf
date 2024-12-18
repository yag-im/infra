variable "create_istio_vs" {
  type    = string
  default = "false"
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "discord_oauth_client_id" {
  type = string
}

variable "google_oauth_client_id" {
  type = string
}

variable "reddit_oauth_client_id" {
  type = string
}

variable "twitch_oauth_client_id" {
  type = string
}

variable "ga_id" {
  type = string
}

variable "ovh_project_id" {
  type = string
}

variable "ovh_vrack_id" {
  type = string
}
