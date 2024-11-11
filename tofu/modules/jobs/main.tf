resource "kubernetes_deployment" "jobs" {
  metadata {
    name = "jobs-deployment"
    labels = {
      app = "jobs"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "jobs"
      }
    }
    template {
      metadata {
        labels = {
          app = "jobs"
        }
      }
      spec {
        container {
          image             = var.docker_image_name
          image_pull_policy = "IfNotPresent"
          name              = "jobs"
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
              name = "jobs-cm"
            }
          }
        }
        dynamic "image_pull_secrets" {
          for_each = var.docker_image_pull_secrets
          content {
            name = image_pull_secrets.value
          }
        }
      }
    }
  }
}

resource "kubernetes_config_map" "jobs" {
  metadata {
    name      = "jobs-cm"
    namespace = var.k8s_namespace
  }
  data = {
    JUKEBOXSVC_URL = "http://jukeboxsvc"
    SESSIONSVC_URL = "http://sessionsvc"
  }
}
