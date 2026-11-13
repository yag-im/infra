resource "kubernetes_deployment" "appsvc" {
  metadata {
    name = "appsvc-deployment"
    labels = {
      app = "appsvc"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "appsvc"
      }
    }
    template {
      metadata {
        labels = {
          app = "appsvc"
        }
      }
      spec {
        container {
          image             = var.docker_image
          image_pull_policy = "IfNotPresent"
          name              = "appsvc"
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
              name = kubernetes_config_map.appsvc.metadata[0].name
            }
          }
          env_from {
            secret_ref {
              name = kubernetes_secret.appsvc.metadata[0].name
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "appsvc" {
  metadata {
    name      = "appsvc"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "appsvc"
    }
    port {
      port = 80
      name = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "appsvc" {
  metadata {
    name      = "appsvc-cm"
    namespace = var.k8s_namespace
  }
  data = {
    DATA_CENTERS                    = jsonencode(var.dc_regions)
    JUKEBOXSVC_URL                  = "http://jukeboxsvc.default.svc.cluster.local"
    RUNNERS_CONF                    = jsonencode(var.runners)
    SQLDB_DBNAME                    = "yag"
    SQLDB_HOST                      = "sqldb.default.svc.cluster.local"
    SQLDB_PORT                      = 5432
    SQLDB_USERNAME                  = "appsvc"
    SQLDB_ENGINE_OPTIONS            = jsonencode({"pool_pre_ping": true, "pool_size": 3, "max_overflow": 3, "pool_timeout": 10, "pool_recycle": 120})
  }
}

resource "kubernetes_secret" "appsvc" {
  metadata {
    name      = "appsvc-secret"
    namespace = var.k8s_namespace
  }
  data = {
    SQLDB_PASSWORD = var.sqldb_password
  }
}
