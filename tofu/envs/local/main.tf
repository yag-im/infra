terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "aws" {
  profile = "yag-dev"
  region  = "us-east-1"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

locals {
  appstor_nodes = [
    {
      host : "host.minikube.internal"
      nfs_port : 12049
      region : "us-west-1"
      ssh_port : 2222
    },
    {
      host : "host.minikube.internal",
      nfs_port : 12050,
      region : "eu-central-1"
      ssh_port : 2200
    }
  ]
  docker_repo_prefix = "docker.io/library"
  hostnames = {
    bastion    = "bastion.${local.public_tld}"
    grafana    = "grafana.${local.public_tld}"
    otelcol_gw = "otelcol-gw.${local.private_tld}"
    webproxy   = local.public_tld
  }
  public_tld     = "yag.mk"
  private_tld    = "yag.internal"
  ver_appsvc     = "dev"
  ver_bastion    = "dev"
  ver_jobs       = "dev"
  ver_jukeboxsvc = "dev"
  ver_portsvc    = "dev"
  ver_sessionsvc = "dev"
  ver_sigsvc     = "dev"
  ver_sqldb      = "dev"
  ver_webapi     = "dev"
  ver_webapp     = "dev"
  ver_webproxy   = "dev"
}

module "appsvc" {
  source          = "../../modules/appsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/appsvc:${local.ver_appsvc}"
  k8s_namespace   = "default"
  replicas        = 3
  # app config
  # should be defined in "West to East" direction for smart RTT configuration
  data_centers = ["us-west-1", "eu-central-1"]
  flask_env    = "development"
  runners = {
    dosbox-x = {
      ver           = "2024.12.04",
      window_system = "x11",
      igpu          = false,
      dgpu          = false
    },
    dosbox-staging = {
      ver           = "0.82.0",
      window_system = "x11",
      igpu          = false,
      dgpu          = false
    },
    dosbox = {
      ver           = "0.74-3",
      window_system = "x11",
      igpu          = false,
      dgpu          = false
    },
    scummvm = {
      ver           = "2.9.0",
      window_system = "x11",
      igpu          = false,
      dgpu          = false
    },
    wine = {
      ver           = "9.0",
      window_system = "x11",
      igpu          = false,
      dgpu          = false
    }
  }
  streamd_reqs = {
    igpu : false,
    dgpu : false
  }
  # secrets
  sqldb_password = data.aws_ssm_parameter.sqldb_appsvc_password.value
}

module "bastion" {
  source          = "../../modules/bastion"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/bastion:${local.ver_bastion}"
  k8s_namespace   = "default"
  env             = "local"
}

module "jobs" {
  source          = "../../modules/jobs"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/jobs:${local.ver_jobs}"
  k8s_namespace   = "default"
  replicas        = 1
}

module "jukeboxsvc" {
  source          = "../../modules/jukeboxsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/jukeboxsvc:${local.ver_jukeboxsvc}"
  k8s_namespace   = "default"
  replicas        = 3
  # app config
  # appstor_pvcs              = module.appstor_nfs.pvcs
  appstor_nodes              = local.appstor_nodes
  appstor_user               = "vagrant"
  jukebox_docker_repo_prefix = "${local.docker_repo_prefix}/jukebox"
  env                        = "local"
  jukebox_nodes = [
    {
      api_uri : "http://host.minikube.internal:12375",
      region : "us-west-1"
    },
    {
      api_uri : "http://host.minikube.internal:12376",
      region : "us-west-1"
    },
    {
      api_uri : "http://host.minikube.internal:12385",
      region : "eu-central-1"
    },
    {
      api_uri : "http://host.minikube.internal:12386",
      region : "eu-central-1"
    }
  ]
  flask_env     = "development"
  signaler_host = local.public_tld                     # this should go in headers (host) from jukebox to sigsvc for a proper routing
  signaler_uri  = "ws://10.108.160.177/webrtc/streamd" # this should be a public gw ip (check kubectl get svc -n istio-gw-public istio-gw-public output)
  stun_uri      = "stun://stun.l.google.com:19302"
  # secrets
  signaler_auth_token = data.aws_ssm_parameter.sigsvc_auth_token.value
}

module "webapp" {
  source          = "../../modules/webapp"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/webapp:${local.ver_webapp}"
  k8s_namespace   = "default"
  replicas        = 3
  app_env         = "dev"
}

module "portsvc" {
  source          = "../../modules/portsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/portsvc:${local.ver_portsvc}"
  k8s_namespace   = "default"
  replicas        = 3
  # app config
  flask_env = "development"
  # secrets
  sqldb_password = data.aws_ssm_parameter.sqldb_portsvc_password.value
}

module "sessionsvc" {
  source          = "../../modules/sessionsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/sessionsvc:${local.ver_sessionsvc}"
  k8s_namespace   = "default"
  replicas        = 3
  # app config
  flask_env = "development"
  # secrets
  sqldb_password = data.aws_ssm_parameter.sqldb_sessionsvc_password.value
}

module "sigsvc" {
  source          = "../../modules/sigsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/sigsvc:${local.ver_sigsvc}"
  k8s_namespace   = "default"
  replicas        = 3
}

module "sqldb" {
  source        = "../../modules/sqldb"
  docker_image  = "${local.docker_repo_prefix}/sqldb:${local.ver_sqldb}"
  k8s_namespace = "default"
  # app config
  host_data_path     = "/data/postgres" # created under: /var/lib/docker/volumes/minikube-mXX/_data/data/postgres in minikube (maps into /var/lib/postgresql/data inside container)
  pgdata             = "/var/lib/postgresql/data"
  pv_name            = "sqldb-data-pv"
  storage_class_name = "csi-hostpath-sc"
  storage_size       = "5Gi"
  timezone           = var.timezone
  yag_db             = "yag"
  # users
  appsvc_user     = "appsvc"
  authsvc_user    = "authsvc"
  portsvc_user    = "portsvc"
  sessionsvc_user = "sessionsvc"
  # secrets
  appsvc_password     = data.aws_ssm_parameter.sqldb_appsvc_password.value
  authsvc_password    = data.aws_ssm_parameter.sqldb_authsvc_password.value
  portsvc_password    = data.aws_ssm_parameter.sqldb_portsvc_password.value
  sessionsvc_password = data.aws_ssm_parameter.sqldb_sessionsvc_password.value
  postgres_password   = data.aws_ssm_parameter.sqldb_postgres_password.value
}

module "webapi" {
  source          = "../../modules/webapi"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/webapi:${local.ver_webapi}"
  k8s_namespace   = "default"
  replicas        = 3
  # app config
  behind_proxy                = true
  flask_env                   = "development"
  oauthlib_insecure_transport = 1
  oauthlib_relax_token_scope  = 1
  # secrets
  flask_secret_key             = data.aws_ssm_parameter.authsvc_flask_secret_key.value
  flask_security_password_salt = data.aws_ssm_parameter.authsvc_flask_security_password_salt.value
  sigsvc_auth_token            = data.aws_ssm_parameter.sigsvc_auth_token.value
  sqldb_password               = data.aws_ssm_parameter.sqldb_authsvc_password.value
  discord_oauth_client_id      = var.discord_oauth_client_id
  discord_oauth_client_secret  = data.aws_ssm_parameter.authsvc_discord_oauth_client_secret.value
  google_oauth_client_id       = var.google_oauth_client_id
  google_oauth_client_secret   = data.aws_ssm_parameter.authsvc_google_oauth_client_secret.value
  reddit_oauth_client_id       = var.reddit_oauth_client_id
  reddit_oauth_client_secret   = var.reddit_oauth_client_secret
  twitch_oauth_client_id       = var.twitch_oauth_client_id
  twitch_oauth_client_secret   = data.aws_ssm_parameter.authsvc_twitch_oauth_client_secret.value
}

module "webproxy" {
  source          = "../../modules/webproxy"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/webproxy:${local.ver_webproxy}"
  k8s_namespace   = "default"
  replicas        = 3
}

# TODO: istio, misc and otel modules should come at the end, otherwise tofu fails to init

module "istio" {
  source          = "../../modules/istio"
  create_istio_vs = var.create_istio_vs
  k8s_namespace   = "default"

  # endpoints exposed through the istio gateways (both public and private)
  hostnames = local.hostnames
}

module "otel" {
  source          = "../../modules/otel"
  create_istio_vs = var.create_istio_vs
  k8s_namespace   = "otel"
  # secrets
  grafana_admin_password = data.aws_ssm_parameter.otel_grafana_admin_password.value
}
