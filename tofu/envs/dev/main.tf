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
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.1"
    }
    ovh = {
      source  = "ovh/ovh"
      version = ">= 0.13.0"
    }
  }
}

provider "aws" {
  profile = "yag-dev"
  region  = "us-east-1"
}

provider "helm" {
  kubernetes {
    config_path    = "./kubeconfig"
    config_context = "kubernetes-admin@yag-k8s"
  }
}

provider "kubernetes" {
  config_path    = "./kubeconfig"
  config_context = "kubernetes-admin@yag-k8s"
}

provider "openstack" {
  auth_url    = "https://auth.cloud.ovh.net/v3/"
  domain_name = "default"
  alias       = "ovh"
}

provider "ovh" {
  alias = "ovh"
}

locals {
  appstor_nodes = [
    {
      host : "192.168.12.200"
      ovh_region : "US-EAST-VA-1"
      region : "us-east-1"
    },
    {
      host : "192.168.13.200"
      ovh_region : "US-WEST-OR-1"
      region : "us-west-1"
    }
  ]
  docker_repo_prefix = "ghcr.io/yag-im"
  hostnames = {
    bastion    = "bastion.${local.public_tld}"
    grafana    = "grafana.${local.public_tld}"
    otelcol_gw = "otelcol-gw.${local.private_tld}"
    webapp   = local.public_tld
  }
  public_tld     = "dev.yag.im"
  private_tld    = "yag.internal"
  ver_appsvc     = "0.1.5"
  ver_bastion    = "0.0.5"
  ver_jobs       = "0.1.3"
  ver_jukeboxsvc = "0.2.2"
  ver_portsvc    = "0.0.18"
  ver_sessionsvc = "0.0.18"
  ver_sigsvc     = "0.1.2"
  ver_sqldb      = "0.0.2"
  ver_webapi     = "0.1.7"
  ver_webapp     = "0.2.6"
}

module "appsvc" {
  source          = "../../modules/appsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/appsvc:${local.ver_appsvc}"
  k8s_namespace   = "default"
  replicas        = 1
  # app config
  # should be defined in "West to East" direction for smart RTT configuration
  data_centers = ["us-west-1"]
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
    },
    retroarch = {
      ver           = "1.21.0",
      window_system = "x11",
      igpu          = false,
      dgpu          = false
    },
    qemu = {
      ver           = "1.21.0",
      window_system = "x11",
      igpu          = false,
      dgpu          = false,
      memory        = 2147483648 # TODO: winxp only requirement
    }
  }
  streamd_reqs = {
    igpu : true,
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
  env             = "dev"
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
  replicas        = 1
  # app config
  # appstor_pvcs              = module.appstor_nfs.pvcs
  appstor_nodes              = local.appstor_nodes
  appstor_user               = "debian"
  jukebox_docker_repo_prefix = "${local.docker_repo_prefix}/jukebox"
  env                        = "dev"
  jukebox_nodes = [
    {
      api_uri : "http://192.168.12.2:2375",
      region : "us-east-1"
    },
    {
      api_uri : "http://192.168.13.2:2375",
      region : "us-west-1"
    }
  ]
  flask_env     = "development"
  signaler_host = local.public_tld                           # this should go in headers (host) from jukebox to sigsvc for a proper routing
  signaler_uri  = "wss://${local.public_tld}/webrtc/streamd" # this should be a public gw ip (check kubectl get svc -n istio-gw-public istio-gw-public output)
  stun_uri      = "stun://stun.l.google.com:19302"
  # secrets
  signaler_auth_token = data.aws_ssm_parameter.sigsvc_auth_token.value
}

module "webapp" {
  source          = "../../modules/webapp"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/webapp:${local.ver_webapp}"
  k8s_namespace   = "default"
  replicas        = 1
  app_env         = "dev"
  ga_id           = var.ga_id
}

# https://help.ovhcloud.com/csm/en-public-cloud-compute-terraform?id=kb_article_view&sysparm_article=KB0050797
module "ovh" {
  source = "../../modules/ovh"

  appstor = {
    flavor          = "b3-8"
    nodes           = local.appstor_nodes
    public_key_path = "${path.root}/../../modules/bastion/files/secrets/dev/id_ed25519.pub"
    volume_size     = 50 # in GBs
  }
  k8s = {
    desired_nodes = 2
    flavor        = "d2-8"
    max_nodes     = 2
    min_nodes     = 1
    ovh_region    = "US-EAST-VA-1"
  }
  networks = [
    {
      gateway : "192.168.0.1"
      ovh_region : "US-EAST-VA-1"
      network : "192.168.0.0/16"
      start : "192.168.1.2" # k8s nodes will obtain IPs from this range
      end : "192.168.1.254"
    },
    {
      gateway : "192.168.0.1"
      ovh_region : "US-WEST-OR-1"
      network : "192.168.0.0/16"
      start : "192.168.2.2" # k8s nodes will obtain IPs from this range
      end : "192.168.2.254"
    }
  ]
  project_id = var.ovh_project_id # OS_TENANT_ID from secrets/openrc
  vrack_id   = var.ovh_vrack_id   # check https://us.ovhcloud.com/manager/#/dedicated/vrack
}

module "portsvc" {
  source          = "../../modules/portsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/portsvc:${local.ver_portsvc}"
  k8s_namespace   = "default"
  replicas        = 1
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
  replicas        = 1
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
  replicas        = 1
}

module "sqldb" {
  source        = "../../modules/sqldb"
  docker_image  = "${local.docker_repo_prefix}/sqldb:${local.ver_sqldb}"
  k8s_namespace = "default"
  # app config
  pgdata             = "/var/lib/postgresql/data"
  pv_name            = ""
  storage_class_name = "csi-cinder-high-speed"
  storage_size       = "10Gi"
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
  replicas        = 1
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
  reddit_oauth_client_secret   = data.aws_ssm_parameter.authsvc_reddit_oauth_client_secret.value
  twitch_oauth_client_id       = var.twitch_oauth_client_id
  twitch_oauth_client_secret   = data.aws_ssm_parameter.authsvc_twitch_oauth_client_secret.value
}

# TODO: istio, misc and otel modules should come at the end, otherwise tofu fails to init

module "istio" {
  source          = "../../modules/istio"
  create_istio_vs = var.create_istio_vs
  k8s_namespace   = "default"

  # endpoints exposed through the istio gateways (both public and private)
  hostnames = local.hostnames
}

module "misc" {
  source          = "../../modules/misc"
  create_istio_vs = var.create_istio_vs

  # certman
  cert_manager_issuer_url = "https://acme-v02.api.letsencrypt.org/directory"
  hostnames               = local.hostnames
}

module "otel" {
  source          = "../../modules/otel"
  create_istio_vs = var.create_istio_vs
  k8s_namespace   = "otel"
  # secrets
  grafana_admin_password = data.aws_ssm_parameter.otel_grafana_admin_password.value
}
