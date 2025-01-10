resource "kubernetes_deployment" "webproxy" {
  metadata {
    name = "webproxy-deployment"
    labels = {
      app = "webproxy"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "webproxy"
      }
    }
    template {
      metadata {
        labels = {
          app = "webproxy"
        }
      }
      spec {
        container {
          image             = var.docker_image
          image_pull_policy = "IfNotPresent"
          name              = "webproxy"
          port {
            container_port = 80
          }
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "125m"
              memory = "50Mi"
            }
          }
          env_from {
            config_map_ref {
              name = "webproxy-cm"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "webproxy" {
  metadata {
    name      = "webproxy"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "webproxy"
    }
    port {
      port = 80
      name = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "webproxy" {
  metadata {
    name      = "webproxy-cm"
    namespace = var.k8s_namespace
  }
  data = {
    SERVER_NAME = "localhost"
    AUTHSVC_URL = "http://webapi.default.svc.cluster.local"
    SIGSVC_URL  = "http://sigsvc.default.svc.cluster.local"
    WEBAPP_URL  = "http://webapp.default.svc.cluster.local"
    WEBAPI_URL  = "http://webapi.default.svc.cluster.local"
  }
}
