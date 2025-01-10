resource "kubernetes_deployment" "webapp" {
  metadata {
    name = "webapp-deployment"
    labels = {
      app = "webapp"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "webapp"
      }
    }
    template {
      metadata {
        labels = {
          app = "webapp"
        }
      }
      spec {
        container {
          image             = var.docker_image
          image_pull_policy = "IfNotPresent"
          name              = "webapp"
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
              name = "webapp-cm"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "webapp" {
  metadata {
    name      = "webapp"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "webapp"
    }
    port {
      port = 80
      name = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "webapp" {
  metadata {
    name      = "webapp-cm"
    namespace = var.k8s_namespace
  }
  data = {
    # for the server-side rendered pages
    API_URL = "http://webapi.default.svc.cluster.local/api"
    APP_ENV = var.app_env
    GA_ID   = var.ga_id
    PORT    = 80
  }
}
