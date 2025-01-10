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

data "aws_ssm_parameter" "sqldb_authsvc_password" {
  name = "/sqldb/authsvc_password"
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

data "aws_ssm_parameter" "authsvc_flask_secret_key" {
  name = "/authsvc/flask_secret_key"
}

data "aws_ssm_parameter" "authsvc_flask_security_password_salt" {
  name = "/authsvc/flask_security_password_salt"
}

data "aws_ssm_parameter" "authsvc_discord_oauth_client_secret" {
  name = "/authsvc/discord_oauth_client_secret"
}

data "aws_ssm_parameter" "authsvc_google_oauth_client_secret" {
  name = "/authsvc/google_oauth_client_secret"
}

data "aws_ssm_parameter" "authsvc_reddit_oauth_client_secret" {
  name = "/authsvc/reddit_oauth_client_secret"
}

data "aws_ssm_parameter" "authsvc_twitch_oauth_client_secret" {
  name = "/authsvc/twitch_oauth_client_secret"
}
