# disable httpsRedirect in istio when running first time, letsencrypt requires an unsecure HTTP connection to validate cert

locals {
  email                  = "k8s-cert-manager@acme.im"
  namespace_cert_manager = "cert-manager"
  issuer_name            = "letsencrypt"
}

resource "helm_release" "cert_manager" {
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  name             = "cert-manager"
  namespace        = local.namespace_cert_manager
  version          = "v1.16.1"
  timeout          = 120
  cleanup_on_fail  = true
  force_update     = true
  create_namespace = true
  set {
    name  = "installCRDs"
    value = true
  }
}

resource "kubernetes_manifest" "letsencrypt_cluster_issuer" {
  count = var.create_istio_vs == "true" ? 1 : 0
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = local.issuer_name
    }
    spec = {
      acme = {
        server = var.cert_manager_issuer_url
        email  = local.email
        privateKeySecretRef = {
          name = local.issuer_name
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "istio"
              }
            }
          }
        ]
      }
    }
  }
  depends_on = [helm_release.cert_manager]
}

resource "kubernetes_manifest" "certificate" {
  count = var.create_istio_vs == "true" ? 1 : 0
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "yag-im-tls"
      namespace = "istio-gw-public" # TODO: this has to be in the istio gws' namespace
    }
    spec = {
      secretName = "yag-im-tls"
      privateKey = {
        algorithm = "RSA"
        size      = 2048
      }
      usages = [
        "server auth",
      ]
      issuerRef = {
        name = local.issuer_name
        kind = "ClusterIssuer"
      }
      dnsNames = [
        var.hostnames["webproxy"],
        var.hostnames["grafana"]
      ]
    }
  }
}
