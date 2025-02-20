resource "kubernetes_deployment" "sigsvc" {
  metadata {
    name = "sigsvc-deployment"
    labels = {
      app = "sigsvc"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "sigsvc"
      }
    }
    template {
      metadata {
        labels = {
          app = "sigsvc"
        }
      }
      spec {
        container {
          image             = var.docker_image
          image_pull_policy = "IfNotPresent"
          name              = "sigsvc"
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
              name = "sigsvc-cm"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "sigsvc" {
  metadata {
    name      = "sigsvc"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "sigsvc"
    }
    port {
      port = 80
      name = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "sigsvc" {
  metadata {
    name      = "sigsvc-cm"
    namespace = var.k8s_namespace
  }
  data = {
    SESSIONSVC_URL = "http://sessionsvc"
  }
}
