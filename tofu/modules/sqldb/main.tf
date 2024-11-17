resource "kubernetes_persistent_volume" "sqldb_data_local" {
  count = var.storage_class_name == "csi-hostpath-sc" ? 1 : 0
  metadata {
    labels = {
      app = "sqldb"
    }
    name = var.pv_name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    capacity = {
      storage = var.storage_size
    }
    persistent_volume_source {
      host_path {
        path = var.host_data_path
      }
    }
    storage_class_name = var.storage_class_name
  }
}

# resource "kubernetes_persistent_volume" "sqldb_data_cinder" {
#   count = var.storage_class_name == "csi-cinder-high-speed" ? 1 : 0
#   metadata {
#     labels = {
#       app = "sqldb"
#     }
#     name = var.pv_name
#   }
#   spec {
#     access_modes = ["ReadWriteOnce"]
#     capacity = {
#       storage = var.storage_size
#     }
#     persistent_volume_reclaim_policy = "Retain"
#     persistent_volume_source {
#       csi {
#         driver = "cinder.csi.openstack.org"
#         volume_handle = "dummy_volume_handle"
#       }      
#     }
#     storage_class_name = var.storage_class_name
#     volume_mode = "Block"
#   }
# }

resource "kubernetes_persistent_volume_claim" "sqldb_data" {
  metadata {
    labels = {
      app = "sqldb"
    }
    name      = "sqldb-data-pvc"
    namespace = var.k8s_namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_size
      }
    }
    storage_class_name = var.storage_class_name
    volume_name        = var.pv_name
  }
}

resource "kubernetes_stateful_set" "sqldb" {
  metadata {
    name = "sqldb-stateful-set"
    labels = {
      app = "sqldb"
    }
    namespace = var.k8s_namespace
  }
  spec {
    service_name = "sqldb"
    replicas     = 1
    selector {
      match_labels = {
        app = "sqldb"
      }
    }
    template {
      metadata {
        labels = {
          app = "sqldb"
        }
      }
      spec {
        container {
          # command = [ "sh", "-c", "echo Starting container... && sleep 6000" ]
          image             = var.docker_image
          image_pull_policy = "IfNotPresent"
          name              = "sqldb"
          env_from {
            config_map_ref {
              name = "sqldb-cm"
            }
          }
          port {
            container_port = 5432
            name           = "postgres"
          }
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
          volume_mount {
            name       = "sqldb-data-mount"
            mount_path = var.pgdata
          }
          lifecycle {
            pre_stop {
              exec {
                command = ["sh", "-c", "pg_ctl -D ${var.pgdata}/pgdata -w -t 60 -m fast stop"]
              }
            }
          }
        }
        volume {
          name = "sqldb-data-mount"
          persistent_volume_claim {
            claim_name = "sqldb-data-pvc"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "sqldb" {
  metadata {
    name      = "sqldb"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "sqldb"
    }
    port {
      port = 5432
      name = "tcp-sqldb"
    }
    cluster_ip = "None"
  }
}

resource "kubernetes_config_map" "sqldb" {
  metadata {
    name      = "sqldb-cm"
    namespace = var.k8s_namespace
  }
  data = {
    APPSVC_USER         = var.appsvc_user
    APPSVC_PASSWORD     = var.appsvc_password
    MCCSVC_USER         = var.mccsvc_user
    MCCSVC_PASSWORD     = var.mccsvc_password
    PGDATA              = "${var.pgdata}/pgdata"
    PORTSVC_USER        = var.portsvc_user
    PORTSVC_PASSWORD    = var.portsvc_password
    POSTGRES_PASSWORD   = var.postgres_password
    SESSIONSVC_USER     = var.sessionsvc_user
    SESSIONSVC_PASSWORD = var.sessionsvc_password
    TZ                  = var.timezone
    YAG_DB              = var.yag_db
    YAGSVC_PASSWORD     = var.yagsvc_password
    YAGSVC_USER         = var.yagsvc_user
  }
}
