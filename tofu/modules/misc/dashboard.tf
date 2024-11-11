locals {
  namespace_dashboard = "kubernetes-dashboard"
}

resource "helm_release" "kubernetes_dashboard" {
  repository       = "https://kubernetes.github.io/dashboard/"
  chart            = "kubernetes-dashboard"
  name             = "kubernetes-dashboard"
  namespace        = local.namespace_dashboard
  version          = "7.2.0"
  timeout          = 120
  cleanup_on_fail  = true
  force_update     = false
  create_namespace = true
  set {
    name  = "cert-manager.enabled"
    value = false
  }
}

resource "kubernetes_service_account" "dashboard_user" {
  metadata {
    name      = "dashboard-user"
    namespace = local.namespace_dashboard
  }
}

resource "kubernetes_cluster_role_binding" "dashboard_user" {
  metadata {
    name = "dashboard-user"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "dashboard-user"
    namespace = local.namespace_dashboard
  }
}

resource "kubernetes_secret" "dashboard_user_token" {
  metadata {
    name      = "dashboard-user-token"
    namespace = local.namespace_dashboard
    annotations = {
      "kubernetes.io/service-account.name" = "dashboard-user"
    }
  }
  type = "kubernetes.io/service-account-token"
}
