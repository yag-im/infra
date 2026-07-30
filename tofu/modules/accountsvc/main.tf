resource "kubernetes_deployment" "accountsvc" {
  metadata {
    name = "accountsvc-deployment"
    labels = {
      app = "accountsvc"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "accountsvc"
      }
    }
    template {
      metadata {
        labels = {
          app = "accountsvc"
        }
      }
      spec {
        container {
          image             = var.docker_image
          image_pull_policy = "IfNotPresent"
          name              = "accountsvc"
          port {
            container_port = 8080
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
              name = kubernetes_config_map.accountsvc.metadata[0].name
            }
          }
          env_from {
            secret_ref {
              name = kubernetes_secret.accountsvc.metadata[0].name
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "accountsvc" {
  metadata {
    name      = "accountsvc"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "accountsvc"
    }
    port {
      port        = 80
      target_port = 8080
      name        = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "accountsvc" {
  metadata {
    name      = "accountsvc-cm"
    namespace = var.k8s_namespace
  }
  data = {
    APP_ENVIRONMENT         = var.app_env
    APP_LOG_LEVEL           = "INFO"
    APP_DB_HOST             = "sqldb.default.svc.cluster.local"
    APP_DB_PORT             = 5432
    APP_DB_USER             = "accountsvc"
    APP_DB_NAME             = "yag"
    OTEL_SERVICE_NAME       = "accountsvc"
    OTEL_TRACES_EXPORTER    = "none"
    OTEL_METRICS_EXPORTER   = "none"
    OTEL_LOGS_EXPORTER      = "none"
  }
}

resource "kubernetes_secret" "accountsvc" {
  metadata {
    name      = "accountsvc-secret"
    namespace = var.k8s_namespace
  }
  data = {
    APP_DB_PASSWORD         = var.sqldb_password
  }
}
