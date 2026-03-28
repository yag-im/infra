locals {
  namespace_headlamp = "headlamp"
}

resource "helm_release" "headlamp" {
  repository       = "https://kubernetes-sigs.github.io/headlamp/"
  chart            = "headlamp"
  name             = "headlamp"
  namespace        = local.namespace_headlamp
  version          = "0.40.0"
  timeout          = 600
  cleanup_on_fail  = true
  force_update     = true
  create_namespace = true
}

resource "kubernetes_secret" "headlamp_token" {
  metadata {
    name      = "headlamp-token"
    namespace = local.namespace_headlamp
    annotations = {
      "kubernetes.io/service-account.name" = "headlamp"
    }
  }
  type       = "kubernetes.io/service-account-token"
  depends_on = [helm_release.headlamp]
}
