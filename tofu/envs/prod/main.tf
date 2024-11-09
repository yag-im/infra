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
  profile = "yag-prod"
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
      host: "192.168.12.200"
      ovh_region: "US-EAST-VA-1"
      region: "us-east-1"
    },
    {
      host: "192.168.13.200"
      ovh_region: "US-WEST-OR-1"
      region: "us-west-1"
    }
  ]
  aws_ecr_repo_host = "070143334704.dkr.ecr.us-east-1.amazonaws.com"
  aws_ecr_repo_region = "us-east-1"
  docker_images_repo_host = "070143334704.dkr.ecr.us-east-1.amazonaws.com" # set equal to aws_ecr_repo_host for dev and prod envs
  docker_images_repo_prefix = "im.acme.yag."
  github_packages_repo_host = "ghcr.io"
  github_packages_repo_name = "yag-im"
  hostnames = {
    bastion    = "bastion.${local.public_tld}"
    grafana    = "grafana.${local.public_tld}"
    #mcc        = "mcc.${local.public_tld}"
    webapp     = local.public_tld
    otelcol_gw = "otelcol-gw.${local.private_tld}"
  }
  public_tld = "yag.im"
  private_tld = "yag.internal"
  ver_appsvc = "0.1.1"
  ver_bastion = "0.0.5"
  ver_jobs = "0.1.0"
  ver_jukeboxsvc = "0.1.0"
  ver_mcc = "TBD"
  ver_mccsvc = "TBD"
  ver_portsvc = "0.0.11"
  ver_sessionsvc = "0.0.17"
  ver_sigsvc = "0.1.0"
  ver_sqldb = "0.0.14"
  ver_webapp = "0.2.0"
  ver_yagsvc = "0.1.3"
}

# Only jukeboxsvc was consuming this resource, but due to server-side copy restrictions, it's now deprecated
# module "appstor_nfs" {
#   source  = "../../modules/appstor_nfs"
#   servers = local.appstor_nodes
# }

module "appsvc" {
  source                    = "../../modules/appsvc"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.github_packages_repo_host}/${local.github_packages_repo_name}/appsvc:${local.ver_appsvc}"
  #docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 2
  # app config
  # should be defined from West to East direction for smart RTT configuration
  data_centers              = ["us-west-1", "us-east-1"]
  flask_env                 = "production"
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
    igpu: true,
    dgpu: false
  }
  # secrets
  sqldb_password            = data.aws_ssm_parameter.sqldb_appsvc_password.value
}

module aws_ecr {
  source                  = "../../modules/aws_ecr"

  aws_ecr_region             = local.aws_ecr_repo_region
  aws_ecr_access_key_id      = data.aws_ssm_parameter.jukeboxsvc_aws_ecr_access_key.value
  aws_ecr_docker_secret_name = var.docker_image_pull_secrets[0]
  aws_ecr_registries         = local.aws_ecr_repo_host
  aws_ecr_secret_access_key  = data.aws_ssm_parameter.jukeboxsvc_aws_ecr_secret_key.value
}

module "bastion" {
  source                    = "../../modules/bastion"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.github_packages_repo_host}/${local.github_packages_repo_name}/bastion:${local.ver_bastion}"
  # docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  env                       = "prod"
}

module "jobs" {
  source                       = "../../modules/jobs"
  create_istio_vs              = var.create_istio_vs
  docker_image_name            = "${local.github_packages_repo_host}/${local.github_packages_repo_name}/jobs:${local.ver_jobs}"
  # docker_image_pull_secrets    = var.docker_image_pull_secrets
  k8s_namespace                = "default"
  replicas                     = 1
}

module "jukeboxsvc" {
  source                    = "../../modules/jukeboxsvc"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.github_packages_repo_host}/${local.github_packages_repo_name}/jukeboxsvc:${local.ver_jukeboxsvc}"
  # docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 2
  # app config
  # appstor_pvcs              = module.appstor_nfs.pvcs
  appstor_nodes             = local.appstor_nodes
  appstor_user              = "debian"
  aws_ecr_host              = local.aws_ecr_repo_host
  aws_ecr_region            = local.aws_ecr_repo_region
  env                       = "prod"
  jukebox_nodes             = [
    {
      api_uri: "http://192.168.12.2:2375",
      region: "us-east-1"
    },
    {
      api_uri: "http://192.168.13.2:2375",
      region: "us-west-1"
    }
  ]
  flask_env                 = "production"
  signaler_host             = local.public_tld # this should go in headers (host) from jukebox to sigsvc for a proper routing
  signaler_uri              = "wss://${local.public_tld}/webrtc" # this should be a public gw ip (check kubectl get svc -n istio-gw-public istio-gw-public output)
  stun_uri                  = "stun://stun.l.google.com:19302"  
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
  replicas                  = 2
}*/

module "webapp" {
  source                    = "../../modules/webapp"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.github_packages_repo_host}/${local.github_packages_repo_name}/webapp:${local.ver_webapp}"
  # docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 2
  app_env                   = "prod"
  ga_id                     = var.ga_id
}

# https://help.ovhcloud.com/csm/en-public-cloud-compute-terraform?id=kb_article_view&sysparm_article=KB0050797
module "ovh" {
  source       = "../../modules/ovh"

  appstor = {
    flavor          = "b3-8"
    nodes           = local.appstor_nodes
    public_key_path = "${path.root}/../../modules/bastion/files/secrets/prod/id_ed25519.pub"
    volume_size     = 100  # in GBs
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
      gateway: "192.168.0.1"
      ovh_region: "US-EAST-VA-1"
      network: "192.168.0.0/16"
      start: "192.168.1.2"  # k8s nodes will obtain IPs from this range
      end: "192.168.1.254"
    },
    {
      gateway: "192.168.0.1"
      ovh_region: "US-WEST-OR-1"
      network: "192.168.0.0/16"
      start: "192.168.2.2"  # k8s nodes will obtain IPs from this range
      end: "192.168.2.254"
    }
  ]
  project_id   = var.ovh_project_id # OS_TENANT_ID from secrets/openrc
  vrack_id     = var.ovh_vrack_id # check https://us.ovhcloud.com/manager/#/dedicated/vrack
}

module "portsvc" {
  source                    = "../../modules/portsvc"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.github_packages_repo_host}/${local.github_packages_repo_name}/portsvc:${local.ver_portsvc}"
  #docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 2
  # app config
  flask_env                 = "production"
  # secrets
  sqldb_password            = data.aws_ssm_parameter.sqldb_portsvc_password.value
}

module "sessionsvc" {
  source                    = "../../modules/sessionsvc"
  create_istio_vs           = var.create_istio_vs
  docker_image_name         = "${local.github_packages_repo_host}/${local.github_packages_repo_name}/sessionsvc:${local.ver_sessionsvc}"
  # docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 2
  # app config
  flask_env                 = "production"
  # secrets
  sqldb_password            = data.aws_ssm_parameter.sqldb_sessionsvc_password.value
}

module "sigsvc" {
  source                       = "../../modules/sigsvc"
  create_istio_vs              = var.create_istio_vs
  docker_image_name            = "${local.github_packages_repo_host}/${local.github_packages_repo_name}/sigsvc:${local.ver_sigsvc}"
  # docker_image_pull_secrets    = var.docker_image_pull_secrets
  k8s_namespace                = "default"
  replicas                     = 2
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
  pgdata                    = "/var/lib/postgresql/data"
  pv_name                   = ""
  storage_class_name        = "csi-cinder-high-speed"
  storage_size              = "10Gi"
  timezone                  = var.timezone
  yag_db                    = "yag"
  # users
  appsvc_user               = "appsvc"
  mccsvc_user               = "mccsvc"
  portsvc_user              = "portsvc"
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
  docker_image_name         = "${local.github_packages_repo_host}/${local.github_packages_repo_name}/yagsvc:${local.ver_yagsvc}"
  # docker_image_pull_secrets = var.docker_image_pull_secrets
  k8s_namespace             = "default"
  replicas                  = 2
  # app config
  behind_proxy                 = true
  flask_env                    = "production"
  oauthlib_insecure_transport  = 1
  oauthlib_relax_token_scope   = 1
  # secrets
  flask_secret_key             = data.aws_ssm_parameter.yagsvc_flask_secret_key.value
  flask_security_password_salt = data.aws_ssm_parameter.yagsvc_flask_security_password_salt.value
  sqldb_password               = data.aws_ssm_parameter.sqldb_yagsvc_password.value
  discord_oauth_client_id      = var.discord_oauth_client_id
  discord_oauth_client_secret  = data.aws_ssm_parameter.yagsvc_discord_oauth_client_secret.value
  google_oauth_client_id       = var.google_oauth_client_id
  google_oauth_client_secret   = data.aws_ssm_parameter.yagsvc_google_oauth_client_secret.value
  reddit_oauth_client_id       = var.reddit_oauth_client_id
  reddit_oauth_client_secret   = data.aws_ssm_parameter.yagsvc_reddit_oauth_client_secret.value
  twitch_oauth_client_id       = var.twitch_oauth_client_id
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

module "misc" {
  source          = "../../modules/misc"
  create_istio_vs = var.create_istio_vs
  
  # certman
  cert_manager_issuer_url = "https://acme-v02.api.letsencrypt.org/directory"
  hostnames               = local.hostnames
}

module "otel" {
  source                 = "../../modules/otel"
  create_istio_vs        = var.create_istio_vs
  k8s_namespace          = "otel"
  # secrets
  grafana_admin_password = data.aws_ssm_parameter.otel_grafana_admin_password.value
}
