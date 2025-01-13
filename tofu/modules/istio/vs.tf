resource "kubernetes_manifest" "virtual_service_bastion" {
  count = var.create_istio_vs == "true" ? 1 : 0
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      labels = {
        app = "bastion"
      }
      name      = "bastion-vs"
      namespace = local.gw_namespace_public
    }
    spec = {
      gateways = [
        local.gw_namespace_public,
      ]
      hosts = [
        var.hostnames["bastion"]
      ]
      tcp = [
        {
          route = [
            {
              destination = {
                host = "bastion.default.svc.cluster.local",
                port = {
                  number = 22
                }
              }
            },
          ]
        },
      ]
    }
  }
}

resource "kubernetes_manifest" "virtual_service_grafana" {
  count = var.create_istio_vs == "true" ? 1 : 0
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      labels = {
        app = "grafana"
      }
      name      = "grafana-vs"
      namespace = local.gw_namespace_public
    }
    spec = {
      gateways = [
        local.gw_name_public,
      ]
      hosts = [
        var.hostnames["grafana"]
      ]
      http = [
        {
          route = [
            {
              destination = {
                host = "grafana.otel.svc.cluster.local",
                port = {
                  number = 80
                }
              }
            },
          ]
        },
      ]
    }
  }
}

# sticky sessions are required so both jukebox node and user connecting to the same signalling node (sigsvc)
# TODO: doesn't work with webproxy, revise design and make proxying queries fully istio-driven
resource "kubernetes_manifest" "destination_rule_sigsvc" {
  count = var.create_istio_vs == "true" ? 1 : 0
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "DestinationRule"
    metadata = {
      name      = "sigsvc-dr",
      namespace = local.gw_namespace_public
    }
    spec = {
      host = "sigsvc.default.svc.cluster.local"
      trafficPolicy = {
        loadBalancer = {
          consistentHash = {
            httpCookie = {
              name = "sigsvc_wsconnid"
              ttl  = "0s"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "virtual_service_webproxy" {
  count = var.create_istio_vs == "true" ? 1 : 0
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      labels = {
        app = "webproxy"
      }
      name      = "webproxy-vs"
      namespace = local.gw_namespace_public
    }
    spec = {
      gateways = [
        local.gw_name_public,
      ]
      hosts = [
        var.hostnames["webproxy"]
      ]
      http = [
        {
          route = [
            {
              destination = {
                host = "webproxy.default.svc.cluster.local",
                port = {
                  number = 80
                }
              }
            }
          ]
        }
      ]
    }
  }
}
