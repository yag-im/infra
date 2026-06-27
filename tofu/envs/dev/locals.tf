locals {
  docker_repo_prefix = "ghcr.io/yag-im"
  public_tld         = "dev.yag.im"
  private_tld        = "yag.internal"

  discord_oauth_client_id          = "1251213147776225341"
  google_oauth_client_id           = "454405087013-0pc1gvsivodjea0dkhb5uqtop3acrkl8.apps.googleusercontent.com"
  reddit_oauth_client_id           = "O4pp1XbXnxKJqMJg28qvnQ"
  twitch_oauth_client_id           = "g9pl60vjz9ejuucgbpnzm0eb78ug4d"
  ga_id                            = "G-MSFJWCPYS9"
  ovh_project_id                   = "d60289206102496ba63a80be4fa0e921"
  ovh_vrack_id                     = "pn-2007865"
  ovh_endpoint                     = "ovh-us"
  os_auth_url                      = "https://auth.cloud.ovh.us/v3"
  os_identity_api_version          = "3"
  os_username                      = "user-rNHnXtcC2j24"

  hostnames = {
    bastion    = "bastion.${local.public_tld}"
    grafana    = "grafana.${local.public_tld}"
    otelcol_gw = "otelcol-gw.${local.private_tld}"
    webapp     = local.public_tld
  }

  svc_versions = {
    appsvc     = "0.3.21"
    bastion    = "0.0.5"
    jobs       = "0.1.19"
    jukeboxsvc = "0.4.24"
    portsvc    = "0.1.6"
    sessionsvc = "0.1.3"
    sigsvc     = "0.1.8"
    sqldb      = "0.0.154"
    webapi     = "0.3.10"
    webapp     = "0.6.22"
  }

  region_mapping = {
    us-east-1 = "US-EAST-VA-1"
    us-west-1 = "US-WEST-OR-1"
  }

  appstor = {
    flavor          = "b3-8"
    public_key_path = "${path.root}/../../modules/bastion/files/secrets/dev/id_ed25519.pub"
    volume_size     = 10
    regions = {
      us-east-1 = {
        nodes = [
          { host = "appstor0-us-east-1" },
          { host = "appstor1-us-east-1" }
        ]
      }
      us-west-1 = {
        nodes = [
          { host = "appstor0-us-west-1" },
          { host = "appstor1-us-west-1" }
        ]
      }
    }
  }

  dc_regions = ["us-west-1", "us-east-1"]

  k8s_core_node_flavor = "d2-8"
  k8s_core_node_count  = 2

  app_runners = {
    dosbox-x = {
      ver           = "2024.12.04"
      window_system = "x11"
      igpu          = false
      dgpu          = false
    }
    dosbox-staging = {
      ver           = "0.82.0"
      window_system = "x11"
      igpu          = false
      dgpu          = false
    }
    dosbox = {
      ver           = "0.74-3"
      window_system = "x11"
      igpu          = false
      dgpu          = false
    }
    scummvm = {
      ver           = "2.9.0"
      window_system = "x11"
      igpu          = false
      dgpu          = false
    }
    wine = {
      ver           = "9.0"
      window_system = "x11"
      igpu          = false
      dgpu          = false
    }
    retroarch = {
      ver           = "1.21.0"
      window_system = "x11"
      igpu          = false
      dgpu          = false
    }
    qemu = {
      ver           = "latest"
      window_system = "x11"
      igpu          = false
      dgpu          = false
      memory        = 2147483648
    }
  }
}
