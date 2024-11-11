variable "create_istio_vs" {
  type    = string
  default = "false"
}

variable "docker_image_pull_secrets" {
  type    = list(any)
  default = ["awsecr-cred"]
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
