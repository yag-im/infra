terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.100.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "= 2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.38.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 3.0.0"
    }
    ovh = {
      source  = "ovh/ovh"
      version = ">= 2.1.0"
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
  auth_url    = "https://auth.cloud.ovh.us/v3/"
  domain_name = "default"
  alias       = "ovh"
}

provider "ovh" {
  alias = "ovh"
}

# --- OVH infrastructure (split into network / k8s) ---

locals {
  ovh_networks = [
    {
      gateway    = "192.168.0.1"
      ovh_region = local.region_mapping["us-east-1"]
      network    = "192.168.0.0/16"
      start      = "192.168.1.2"
      end        = "192.168.1.254"
    },
    {
      gateway    = "192.168.0.1"
      ovh_region = local.region_mapping["us-west-1"]
      network    = "192.168.0.0/16"
      start      = "192.168.2.2"
      end        = "192.168.2.254"
    }
  ]
}

module "ovh_network" {
  source = "../../modules/ovh_network"

  project_id   = local.ovh_project_id
  vrack_id     = local.ovh_vrack_id
  network_name = "yag-pn"
  networks     = local.ovh_networks
}

module "ovh_k8s" {
  source = "../../modules/ovh_k8s"

  project_id = local.ovh_project_id
  k8s = {
    desired_nodes = local.k8s_core_node_count
    flavor        = local.k8s_core_node_flavor
    max_nodes     = local.k8s_core_node_count
    min_nodes     = 1
    ovh_region    = local.region_mapping["us-east-1"]
  }
  private_network_regions_attributes = module.ovh_network.private_network_regions_attributes
  private_subnets                    = module.ovh_network.private_subnets
  network_ready                      = module.ovh_network.network_ready
  kubeconfig_filename                = "kubeconfig"
}

# for DNS resolution from K8S to VMs
module "ovh_vms" {
  source = "../../modules/ovh_vms"

  jukebox_nodes = [
    {
      region         = "us-east-1"
      base_ip_prefix = "192.168.12"
    },
    {
      region         = "us-west-1"
      base_ip_prefix = "192.168.13"
    }
  ]
  appstor_nodes = [
    {
      region         = "us-east-1"
      base_ip_prefix = "192.168.12"
      count          = 1
    },
    {
      region         = "us-west-1"
      base_ip_prefix = "192.168.13"
      count          = 1
    }
  ]
}

# --- PostgreSQL database ---

module "sqldb" {
  source        = "../../modules/sqldb"
  docker_image  = "${local.docker_repo_prefix}/sqldb:${local.svc_versions.sqldb}"
  k8s_namespace = "default"
  # app config
  pgdata             = "/var/lib/postgresql/data"
  pv_name            = ""
  storage_class_name = "csi-cinder-high-speed"
  storage_size       = "10Gi"
  timezone           = var.timezone
  yag_db             = "yag"
  # users
  accountsvc_user = "accountsvc"
  appsvc_user     = "appsvc"
  authsvc_user    = "authsvc"
  jukeboxsvc_user = "jukeboxsvc"
  portsvc_user    = "portsvc"
  sessionsvc_user = "sessionsvc"
  # secrets
  accountsvc_password  = data.aws_ssm_parameter.sqldb_accountsvc_password.value
  appsvc_password      = data.aws_ssm_parameter.sqldb_appsvc_password.value
  authsvc_password     = data.aws_ssm_parameter.sqldb_authsvc_password.value
  jukeboxsvc_password  = data.aws_ssm_parameter.sqldb_jukeboxsvc_password.value
  portsvc_password     = data.aws_ssm_parameter.sqldb_portsvc_password.value
  sessionsvc_password  = data.aws_ssm_parameter.sqldb_sessionsvc_password.value
  postgres_password    = data.aws_ssm_parameter.sqldb_postgres_password.value
}

# --- Application Services ---

module "appsvc" {
  source          = "../../modules/appsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/appsvc:${local.svc_versions.appsvc}"
  k8s_namespace   = "default"
  replicas        = 1
  # app config
  dc_regions   = local.dc_regions
  flask_env    = "development"
  runners      = local.app_runners
  # secrets
  sqldb_password = data.aws_ssm_parameter.sqldb_appsvc_password.value
}

module "bastion" {
  source          = "../../modules/bastion"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/bastion:${local.svc_versions.bastion}"
  k8s_namespace   = "default"
  env             = "dev"
}

module "jobs" {
  source          = "../../modules/jobs"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/jobs:${local.svc_versions.jobs}"
  k8s_namespace   = "default"
  replicas        = 1

  enable_cluster_sync_job  = true
  enable_cluster_scale_job = false
  enable_sessions_trim_job = true
}

module "jukeboxsvc" {
  source          = "../../modules/jukeboxsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/jukeboxsvc:${local.svc_versions.jukeboxsvc}"
  k8s_namespace   = "default"
  replicas        = 1
  # app config
  appstor_user               = "debian"
  jukebox_docker_repo_prefix = "${local.docker_repo_prefix}/jukebox"
  app_env                    = "dev"
  flask_env                  = "development"
  ovh_project_id             = local.ovh_project_id
  ovh_endpoint               = local.ovh_endpoint
  os_auth_url                = local.os_auth_url
  os_identity_api_version    = local.os_identity_api_version
  os_username                = local.os_username
  signaler_host              = local.public_tld                           # this should go in headers (host) from jukebox to sigsvc for a proper routing
  signaler_uri               = "wss://${local.public_tld}/webrtc/streamd" # this should be a public gw ip (check kubectl get svc -n istio-gw-public istio-gw-public output)
  stun_uri                   = "stun://stun.l.google.com:19302"
  # secrets
  signaler_auth_token    = data.aws_ssm_parameter.sigsvc_auth_token.value
  sqldb_password         = data.aws_ssm_parameter.sqldb_jukeboxsvc_password.value
  ovh_application_key    = data.aws_ssm_parameter.ovh_application_key.value
  ovh_application_secret = data.aws_ssm_parameter.ovh_application_secret.value
  ovh_consumer_key       = data.aws_ssm_parameter.ovh_consumer_key.value
  os_password            = data.aws_ssm_parameter.os_password.value
}

module "webapp" {
  source          = "../../modules/webapp"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/webapp:${local.svc_versions.webapp}"
  k8s_namespace   = "default"
  replicas        = 1
  app_env         = "dev"
  ga_id           = local.ga_id
}

module "portsvc" {
  source          = "../../modules/portsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/portsvc:${local.svc_versions.portsvc}"
  k8s_namespace   = "default"
  replicas        = 1
  # app config
  flask_env = "development"
  # secrets
  sqldb_password             = data.aws_ssm_parameter.sqldb_portsvc_password.value
  twitch_oauth_client_id     = local.twitch_oauth_client_id
  twitch_oauth_client_secret = data.aws_ssm_parameter.authsvc_twitch_oauth_client_secret.value
}

module "sessionsvc" {
  source          = "../../modules/sessionsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/sessionsvc:${local.svc_versions.sessionsvc}"
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
  docker_image    = "${local.docker_repo_prefix}/sigsvc:${local.svc_versions.sigsvc}"
  k8s_namespace   = "default"
  replicas        = 1
}

module "webapi" {
  source          = "../../modules/webapi"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/webapi:${local.svc_versions.webapi}"
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
  discord_oauth_client_id      = local.discord_oauth_client_id
  discord_oauth_client_secret  = data.aws_ssm_parameter.authsvc_discord_oauth_client_secret.value
  google_oauth_client_id       = local.google_oauth_client_id
  google_oauth_client_secret   = data.aws_ssm_parameter.authsvc_google_oauth_client_secret.value
  reddit_oauth_client_id       = local.reddit_oauth_client_id
  reddit_oauth_client_secret   = data.aws_ssm_parameter.authsvc_reddit_oauth_client_secret.value
  twitch_oauth_client_id       = local.twitch_oauth_client_id
  twitch_oauth_client_secret   = data.aws_ssm_parameter.authsvc_twitch_oauth_client_secret.value
}

module "accountsvc" {
  source          = "../../modules/accountsvc"
  create_istio_vs = var.create_istio_vs
  docker_image    = "${local.docker_repo_prefix}/accountsvc:${local.svc_versions.accountsvc}"
  k8s_namespace   = "default"
  replicas        = 1
  # app config
  app_env         = "dev"
  # secrets
  sqldb_password = data.aws_ssm_parameter.sqldb_accountsvc_password.value
}

# TODO: istio, misc and otel modules should come at the end, otherwise tofu fails to init

module "istio" {
  source          = "../../modules/istio"
  create_istio_vs = var.create_istio_vs
  k8s_namespace   = "default"

  # endpoints exposed through the istio gateways (both public and private)
  hostnames            = local.hostnames
  private_lb_subnet_id = module.ovh_network.private_lb_subnet_id
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
