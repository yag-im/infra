# https://us-east-1.console.aws.amazon.com/systems-manager/parameters/?region=us-east-1&tab=Table

data "aws_ssm_parameter" "otel_grafana_admin_password" {
  name = "/otel/grafana_admin_password"
}

data "aws_ssm_parameter" "sigsvc_auth_token" {
  name = "/sigsvc/auth_token"
}

data "aws_ssm_parameter" "sqldb_appsvc_password" {
  name = "/sqldb/appsvc_password"
}

data "aws_ssm_parameter" "sqldb_mccsvc_password" {
  name = "/sqldb/mccsvc_password"
}

data "aws_ssm_parameter" "sqldb_portsvc_password" {
  name = "/sqldb/portsvc_password"
}

data "aws_ssm_parameter" "sqldb_postgres_password" {
  name = "/sqldb/postgres_password"
}

data "aws_ssm_parameter" "sqldb_sessionsvc_password" {
  name = "/sqldb/sessionsvc_password"
}

data "aws_ssm_parameter" "sqldb_yagsvc_password" {
  name = "/sqldb/yagsvc_password"
}

data "aws_ssm_parameter" "yagsvc_flask_secret_key" {
  name = "/yagsvc/flask_secret_key"
}

data "aws_ssm_parameter" "yagsvc_flask_security_password_salt" {
  name = "/yagsvc/flask_security_password_salt"
}

data "aws_ssm_parameter" "yagsvc_discord_oauth_client_secret" {
  name = "/yagsvc/discord_oauth_client_secret"
}

data "aws_ssm_parameter" "yagsvc_google_oauth_client_secret" {
  name = "/yagsvc/google_oauth_client_secret"
}

data "aws_ssm_parameter" "yagsvc_twitch_oauth_client_secret" {
  name = "/yagsvc/twitch_oauth_client_secret"
}

# ideally should be part of aws_ssm_parameter, but reddit doesn't allow to share same secret for multiple envs
variable "reddit_oauth_client_secret" {
  type = string
}
