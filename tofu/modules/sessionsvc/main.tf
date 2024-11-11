resource "kubernetes_deployment" "sessionsvc" {
  metadata {
    name = "sessionsvc-deployment"
    labels = {
      app = "sessionsvc"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "sessionsvc"
      }
    }
    template {
      metadata {
        labels = {
          app = "sessionsvc"
        }
      }
      spec {
        container {
          image             = var.docker_image_name
          image_pull_policy = "IfNotPresent"
          name              = "sessionsvc"
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
              name = "sessionsvc-cm"
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

resource "kubernetes_service" "sessionsvc" {
  metadata {
    name      = "sessionsvc"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "sessionsvc"
    }
    port {
      port = 80
      name = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "sessionsvc" {
  metadata {
    name      = "sessionsvc-cm"
    namespace = var.k8s_namespace
  }
  data = {
    FLASK_DEBUG                     = true
    FLASK_ENV                       = var.flask_env
    FLASK_PROPAGATE_EXCEPTIONS      = true
    FLASK_SQLALCHEMY_ENGINE_OPTIONS = "{\"pool_pre_ping\": true, \"pool_size\": 10, \"pool_recycle\": 120}"
    APPSVC_URL                      = "http://appsvc.default.svc.cluster.local"
    SQLDB_DBNAME                    = "yag"
    SQLDB_HOST                      = "sqldb.default.svc.cluster.local"
    SQLDB_PORT                      = 5432
    SQLDB_USERNAME                  = "sessionsvc"
    #secrets
    SQLDB_PASSWORD = var.sqldb_password
  }
}
