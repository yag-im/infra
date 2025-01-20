locals {
  url_charts_istio     = "https://istio-release.storage.googleapis.com/charts"
  ver_charts_istio     = "1.24.2"
  gw_selector_public   = "istio-ingressgateway"
  gw_selector_private  = "sel-gw-private"
  gw_namespace_public  = "istio-gw-public"
  gw_namespace_private = "istio-gw-private"
  gw_name_public       = "istio-gw-public"
  gw_name_private      = "istio-gw-private"
}

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
    labels = {
      istio-injection = "enabled"
    }
  }
}

resource "helm_release" "istio_base" {
  repository      = local.url_charts_istio
  chart           = "base"
  name            = "istio-base"
  namespace       = kubernetes_namespace.istio_system.metadata.0.name
  version         = local.ver_charts_istio
  timeout         = 120
  cleanup_on_fail = true
  force_update    = false
}

resource "helm_release" "istiod" {
  repository      = local.url_charts_istio
  chart           = "istiod"
  name            = "istiod"
  namespace       = kubernetes_namespace.istio_system.metadata.0.name
  version         = local.ver_charts_istio
  timeout         = 120
  cleanup_on_fail = true
  force_update    = false
  values = [
    templatefile("${path.module}/manifests/istiod.yaml", {
      gw_name = "${local.gw_name_public}"
      gw_selector = "${local.gw_selector_public}"
      authsvc = "webapi.default.svc.cluster.local"
    })
  ]
  
  depends_on = [helm_release.istio_base]
}

resource "kubernetes_namespace" "istio_gw_public" {
  metadata {
    name = local.gw_namespace_public
    labels = {
      istio-injection = "enabled"
    }
  }
}

resource "helm_release" "istio_gw_public" {
  repository      = local.url_charts_istio
  chart           = "gateway"
  name            = local.gw_name_public
  namespace       = kubernetes_namespace.istio_gw_public.metadata.0.name
  version         = local.ver_charts_istio
  timeout         = 500
  cleanup_on_fail = true
  force_update    = false
  depends_on      = [helm_release.istiod]
  values = [
    templatefile("${path.module}/manifests/gw-public.yaml", {
      gw_selector = "${local.gw_selector_public}"
    })
  ]
}

resource "kubernetes_manifest" "istio_auth_policy_user" {
  count = var.create_istio_vs == "true" ? 1 : 0
  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "user-auth-policy"
      namespace = kubernetes_namespace.istio_gw_public.metadata.0.name
    }
    spec = {
      action = "CUSTOM"
      provider = {
        name = "ext-authz-http"
      }
      rules = [
        {
          to = [
            {
              operation = {
                hosts = [var.hostnames["webapp"]]
                paths = ["/api/*", "/webrtc"]
                notPaths = ["/api/docs", "/api/specs", "/api/apps"]
              }
            }
          ]
        }
      ],
      selector = {
        matchLabels = {
          app = local.gw_name_public
        }
      }
    }
  }
}

resource "kubernetes_manifest" "istio_gw_public" {
  count = var.create_istio_vs == "true" ? 1 : 0
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = local.gw_name_public
      namespace = kubernetes_namespace.istio_gw_public.metadata.0.name
    }
    spec = {
      selector = {
        istio = local.gw_selector_public
      }
      servers = [
        { # bastion
          hosts = [
            var.hostnames["bastion"]
          ]
          port = {
            name     = "bastion"
            number   = 22
            protocol = "TCP"
          }
        },
        { # web facing endpoints
          hosts = [
            var.hostnames["grafana"],
            var.hostnames["webapp"]
          ]
          port = {
            name     = "https"
            number   = 443
            protocol = "HTTPS"
          }
          tls = {
            mode           = "SIMPLE"
            credentialName = "yag-im-tls"
          }
        },
        { # web facing endpoints (unsecure, for local tests only)
          hosts = [
            var.hostnames["grafana"],
            var.hostnames["webapp"]
          ]
          port = {
            name     = "http"
            number   = 80
            protocol = "HTTP"
          }
          tls = {
            httpsRedirect = false
          }
        },
      ]
    }
  }
}

# private gw setup
/* TODO: OVHs' K8S doesn't support private IPs assignments

The new technology is an OpenStack-based load balancer. 
It's highly configurable, compatible with private IPs, and can be managed via OpenStack or the OVHcloud API. 
Unfortunately, it's in the end stages of testing for use as a Kubernetes object and not yet available in this context. 
It can still be used as an OpenStack resource in parallel with a Kubernetes cluster, just not managed with K8s APIs.
Openstack loadbalancer doc: https://support.us.ovhcloud.com/hc/en-us/articles/18610207964051-Getting-Started-with-Load-Balancer-on-Public-Cloud

resource "kubernetes_namespace" "istio_gw_private" {
  metadata {
    name = local.gw_namespace_private
    labels = {
      istio-injection = "enabled"
    }
  }
}

resource "helm_release" "istio_gw_private" {
  repository      = local.url_charts_istio
  chart           = "gateway"
  name            = local.gw_name_private
  namespace       = kubernetes_namespace.istio_gw_private.metadata.0.name
  version         = local.ver_charts_istio
  timeout         = 500
  cleanup_on_fail = true
  force_update    = false
  depends_on      = [helm_release.istiod]
  values = [
    templatefile("${path.module}/manifests/gw-private.yaml", {
        gw_selector = "${local.gw_selector_private}"
    })
  ]
}

resource "kubernetes_manifest" "istio_gw_private" {
  count = var.create_istio_vs == "true" ? 1 : 0
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = local.gw_name_private
      namespace = kubernetes_namespace.istio_gw_private.metadata.0.name
    }
    spec = {
      selector = {
        istio = local.gw_selector_private
      }
      servers = [
        { # otelcol-gw
          hosts = [
            var.hostnames["otelcol_gw"]
          ]
          port = {
            name = "otelcol-gw"
            number   = 4317
            protocol = "TCP"            
          }
        }
      ]
    }
  }
}
*/
