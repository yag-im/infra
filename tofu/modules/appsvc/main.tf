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
              name = "appsvc-cm"
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
    DATA_CENTERS                    = jsonencode(var.data_centers)
    FLASK_DEBUG                     = true
    FLASK_ENV                       = var.flask_env
    FLASK_PROPAGATE_EXCEPTIONS      = true
    FLASK_SQLALCHEMY_ENGINE_OPTIONS = "{\"pool_pre_ping\": true, \"pool_size\": 10, \"pool_recycle\": 120}"
    JUKEBOXSVC_URL                  = "http://jukeboxsvc.default.svc.cluster.local"
    RUNNERS_CONF                    = jsonencode(var.runners)
    STREAMD_REQS                    = jsonencode(var.streamd_reqs)
    SQLDB_DBNAME                    = "yag"
    SQLDB_HOST                      = "sqldb.default.svc.cluster.local"
    SQLDB_PORT                      = 5432
    SQLDB_USERNAME                  = "appsvc"
    #secrets
    SQLDB_PASSWORD = var.sqldb_password
  }
}
