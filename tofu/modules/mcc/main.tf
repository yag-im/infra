resource "kubernetes_deployment" "mcc" {
  metadata {
    name = "mcc-deployment"
    labels = {
      app = "mcc"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "mcc"
      }
    }
    template {
      metadata {
        labels = {
          app = "mcc"
        }
      }
      spec {
        container {
          image             = var.docker_image
          image_pull_policy = "IfNotPresent"
          name              = "mcc"
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
              name = "mcc-cm"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mcc" {
  metadata {
    name      = "mcc"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "mcc"
    }
    port {
      port = 80
      name = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "mcc" {
  metadata {
    name      = "mcc-cm"
    namespace = var.k8s_namespace
  }
  data = {
    API_URL = "http://yagsvc.default.svc.cluster.local/api"
    PORT    = 80
  }
}
