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

# app config

# this is important for generating valid urls (https instead of http in oauth redirect url)
variable "behind_proxy" {
  type    = bool
  default = false
}

variable "flask_env" {
  type = string
}

variable "oauthlib_insecure_transport" {
  type = string
}

variable "oauthlib_relax_token_scope" {
  type = string
}

# app secrets

variable "flask_secret_key" {
  type = string
}

variable "flask_security_password_salt" {
  type = string
}

variable "sqldb_password" {
  type = string
}

variable "discord_oauth_client_id" {
  type = string
}

variable "discord_oauth_client_secret" {
  type = string
}

variable "google_oauth_client_id" {
  type = string
}

variable "google_oauth_client_secret" {
  type = string
}

variable "reddit_oauth_client_id" {
  type = string
}

variable "reddit_oauth_client_secret" {
  type = string
}

variable "twitch_oauth_client_id" {
  type = string
}

variable "twitch_oauth_client_secret" {
  type = string
}
