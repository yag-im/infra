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
      host: "host.minikube.internal"
      nfs_port: 12049
      region: "us-west-1"
      ssh_port: 2222
    },
    {
      host: "host.minikube.internal",
      nfs_port: 12050,
      region: "eu-central-1"
      ssh_port: 2200
    }
  ]
  aws_ecr_repo_host = "070143334704.dkr.ecr.us-east-1.amazonaws.com"
  aws_ecr_repo_region = "us-east-1"
  docker_images_repo_host = "docker.io" # set equal to aws_ecr_repo_host for dev and prod envs
  docker_images_repo_prefix = "library/"
  hostnames = {
    bastion    = "bastion.${local.public_tld}"
    grafana    = "grafana.${local.public_tld}"
    mcc        = "mcc.${local.public_tld}"
    webapp     = local.public_tld
    otelcol_gw = "otelcol-gw.${local.private_tld}"
  }
  public_tld = "yag.mk"
  private_tld = "yag.internal"
  ver_appsvc = "dev"
  ver_bastion = "dev"
  ver_jobs = "dev"
  ver_jukeboxsvc = "dev"
  ver_mcc = "dev"
  ver_mccsvc = "dev"
  ver_portsvc = "dev"
  ver_sessionsvc = "dev"
  ver_sigsvc = "dev"
  ver_sqldb = "dev"
  ver_webapp = "dev"
  ver_yagsvc = "dev"
}

# Only jukeboxsvc was consuming this resource, but due to server-side copy restrictions, it's now deprecated
# module "appstor_nfs" {
#   source  = "../../modules/appstor_nfs"
#   servers = local.appstor_nodes
# }

module "appsvc" {
  source                    = "../../modules/appsvc"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.docker_images_repo_host}/${local.docker_images_repo_prefix}appsvc:${local.ver_appsvc}"
  docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 3
  # app config
  # should be defined from West to East direction for smart RTT configuration
  data_centers              = ["us-west-1", "eu-central-1"]
  flask_env                 = "development"
  jukebox_container_image_rev = "latest"
  runners                   = {
    dosbox-x = {
      ver = "2024.03.01", 
      window_system = "x11", 
      igpu = false,
      dgpu = false
    },
        dosbox-staging = {
      ver = "0.81.1", 
      window_system = "x11",
      igpu = false,
      dgpu = false
    },
    dosbox = {
      ver = "0.74-3-4", 
      window_system = "x11",
      igpu = false,
      dgpu = false
    },
    scummvm = {
      ver = "2.8.1", 
      window_system = "x11", 
      igpu = false,
      dgpu = false
    },
    wine = {
      ver = "9.0.0.0",
      window_system = "x11", 
      igpu = false,
      dgpu = false
    }
  }
  streamd_reqs              = {
    igpu: false,
    dgpu: false
  }
  # secrets
  sqldb_password            = data.aws_ssm_parameter.sqldb_appsvc_password.value
}

module "bastion" {
  source                    = "../../modules/bastion"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.docker_images_repo_host}/${local.docker_images_repo_prefix}infra.bastion:${local.ver_bastion}"
  docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  env                       = "local"
}

module "jobs" {
  source                       = "../../modules/jobs"
  create_istio_vs              = var.create_istio_vs
  docker_image_name            = "${local.docker_images_repo_host}/${local.docker_images_repo_prefix}jobs:${local.ver_jobs}"
  docker_image_pull_secrets    = var.docker_image_pull_secrets
  k8s_namespace                = "default"
  replicas                     = 1
}

module "jukeboxsvc" {
  source                    = "../../modules/jukeboxsvc"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.docker_images_repo_host}/${local.docker_images_repo_prefix}jukeboxsvc:${local.ver_jukeboxsvc}"
  docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 3
  # app config
  # appstor_pvcs              = module.appstor_nfs.pvcs
  appstor_nodes             = local.appstor_nodes
  appstor_user              = "vagrant"
  aws_ecr_host              = local.aws_ecr_repo_host
  aws_ecr_region            = local.aws_ecr_repo_region
  jukebox_nodes             = [
    {
      api_uri: "http://host.minikube.internal:12375",
      region: "us-west-1"
    },
    {
      api_uri: "http://host.minikube.internal:12376",
      region: "us-west-1"
    },
    {
      api_uri: "http://host.minikube.internal:12385",
      region: "eu-central-1"
    },
    {
      api_uri: "http://host.minikube.internal:12386",
      region: "eu-central-1"
    }
  ]
  flask_env                 = "development"
  signaler_host             = local.public_tld # this should go in headers (host) from jukebox to sigsvc for a proper routing
  signaler_uri              = "ws://10.108.160.177/webrtc" # this should be a public gw ip (check kubectl get svc -n istio-gw-public istio-gw-public output)
  stun_uri                  = "stun://10.0.2.2:3478"  
  # secrets
  aws_ecr_access_key        = data.aws_ssm_parameter.jukeboxsvc_aws_ecr_access_key.value
  aws_ecr_secret_key        = data.aws_ssm_parameter.jukeboxsvc_aws_ecr_secret_key.value
  signaler_auth_token       = data.aws_ssm_parameter.sigsvc_auth_token.value
}

/*
module "mcc" {
  source                    = "../../modules/mcc"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.docker_images_repo_host}/${local.docker_images_repo_prefix}mcc:${local.ver_mcc}"
  docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 3
}*/

module "webapp" {
  source                    = "../../modules/webapp"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.docker_images_repo_host}/${local.docker_images_repo_prefix}webapp:${local.ver_webapp}"
  docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 3
  app_env                   = "dev"
}

module "sessionsvc" {
  source                    = "../../modules/sessionsvc"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.docker_images_repo_host}/${local.docker_images_repo_prefix}sessionsvc:${local.ver_sessionsvc}"
  docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 3
  # app config
  flask_env                 = "development"
  # secrets
  sqldb_password            = data.aws_ssm_parameter.sqldb_sessionsvc_password.value
}

module "sigsvc" {
  source                       = "../../modules/sigsvc"
  create_istio_vs              = var.create_istio_vs
  docker_image_name            = "${local.docker_images_repo_host}/${local.docker_images_repo_prefix}webrtc.sigsvc:${local.ver_sigsvc}"
  docker_image_pull_secrets    = var.docker_image_pull_secrets
  k8s_namespace                = "default"
  replicas                     = 3
  # app config
  debug_no_auth                = "false"
  # secrets
  auth_token                   = data.aws_ssm_parameter.sigsvc_auth_token.value
  flask_secret_key             = data.aws_ssm_parameter.yagsvc_flask_secret_key.value
  flask_security_password_salt = data.aws_ssm_parameter.yagsvc_flask_security_password_salt.value
}

module "sqldb" {
  source                    = "../../modules/sqldb"
  docker_image_name         = "${local.docker_images_repo_host}/${local.docker_images_repo_prefix}sqldb:${local.ver_sqldb}"
  docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  # app config
  host_data_path            = "/data/postgres" # created under: /var/lib/docker/volumes/minikube-mXX/_data/data/postgres in minikube (maps into /var/lib/postgresql/data inside container)
  pgdata                    = "/var/lib/postgresql/data"
  pv_name                   = "sqldb-data-pv"
  storage_class_name        = "csi-hostpath-sc"
  storage_size              = "5Gi"
  timezone                  = var.timezone
  yag_db                    = "yag"
  # users
  appsvc_user               = "appsvc"
  mccsvc_user               = "mccsvc"
  sessionsvc_user           = "sessionsvc"
  yagsvc_user               = "yagsvc"
  # secrets
  appsvc_password           = data.aws_ssm_parameter.sqldb_appsvc_password.value
  mccsvc_password           = data.aws_ssm_parameter.sqldb_mccsvc_password.value
  portsvc_password          = data.aws_ssm_parameter.sqldb_portsvc_password.value
  sessionsvc_password       = data.aws_ssm_parameter.sqldb_sessionsvc_password.value
  postgres_password         = data.aws_ssm_parameter.sqldb_postgres_password.value
  yagsvc_password           = data.aws_ssm_parameter.sqldb_yagsvc_password.value
}

module "yagsvc" {
  source                    = "../../modules/yagsvc"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.docker_images_repo_host}/${local.docker_images_repo_prefix}yagsvc:${local.ver_yagsvc}"
  docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 3
  # app config
  flask_env                    = "development"
  oauthlib_insecure_transport  = 1
  oauthlib_relax_token_scope   = 1
  # secrets
  flask_secret_key             = data.aws_ssm_parameter.yagsvc_flask_secret_key.value
  flask_security_password_salt = data.aws_ssm_parameter.yagsvc_flask_security_password_salt.value
  sqldb_password               = data.aws_ssm_parameter.sqldb_yagsvc_password.value
  discord_oauth_client_id      = "1251213147776225341"
  discord_oauth_client_secret  = data.aws_ssm_parameter.yagsvc_discord_oauth_client_secret.value
  google_oauth_client_id       = "454405087013-0pc1gvsivodjea0dkhb5uqtop3acrkl8.apps.googleusercontent.com"
  google_oauth_client_secret   = data.aws_ssm_parameter.yagsvc_google_oauth_client_secret.value
  reddit_oauth_client_id       = "kXSkfBAREynS_KfNudZFUg"
  reddit_oauth_client_secret   = "9x8SUgofw0VcAruQOiKB2EzulYqYIw" # single aws dev properties can't be shared for multiple reddit apps
  twitch_oauth_client_id       = "g9pl60vjz9ejuucgbpnzm0eb78ug4d"
  twitch_oauth_client_secret   = data.aws_ssm_parameter.yagsvc_twitch_oauth_client_secret.value
}

# TODO: istio, misc and otel modules should come at the end, otherwise tofu fails to init

module "istio" {
  source          = "../../modules/istio"
  create_istio_vs = var.create_istio_vs
  k8s_namespace   = "default"  
  
  # endpoints exposed through the istio gateways (both public and private)
  hostnames       = local.hostnames
}

module "otel" {
  source                 = "../../modules/otel"
  create_istio_vs        = var.create_istio_vs
  k8s_namespace          = "otel"
  # secrets
  grafana_admin_password = data.aws_ssm_parameter.otel_grafana_admin_password.value
}
