resource "kubernetes_deployment" "jukeboxsvc" {
  metadata {
    name = "jukeboxsvc-deployment"
    labels = {
      app = "jukeboxsvc"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "jukeboxsvc"
      }
    }
    template {
      metadata {
        labels = {
          app = "jukeboxsvc"
        }
      }
      spec {
        container {
          image             = var.docker_image
          image_pull_policy = "IfNotPresent"
          name              = "jukeboxsvc"
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
              name = "jukeboxsvc-cm"
            }
          }
          volume_mount {
            name       = "jukeboxsvc-ssh-keys-volume"
            mount_path = "/opt/yag/jukeboxsvc/.ssh"
          }
          # dynamic "volume_mount" {
          #   for_each = var.appstor_pvcs
          #   content {
          #     name       = "${volume_mount.value.name}-mount"
          #     mount_path = "/mnt/appstor/${volume_mount.value.region}"
          #   }
          # }
        }
        volume {
          name = "jukeboxsvc-ssh-keys-volume"
          secret {
            secret_name  = "jukeboxsvc-ssh-keys"
            default_mode = "0400"
          }
        }
        # dynamic "volume" {
        #   for_each = var.appstor_pvcs
        #   content {
        #     name = "${volume.value.name}-mount"
        #     persistent_volume_claim {
        #       claim_name = volume.value.name
        #     }
        #   }
        # }
      }
    }
  }
}

resource "kubernetes_service" "jukeboxsvc" {
  metadata {
    name      = "jukeboxsvc"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "jukeboxsvc"
    }
    port {
      port = 80
      name = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "jukeboxsvc" {
  metadata {
    name      = "jukeboxsvc-cm"
    namespace = var.k8s_namespace
  }
  data = {
    APPSTOR_NODES                                     = jsonencode(var.appstor_nodes)
    APPSTOR_USER                                      = var.appstor_user
    FLASK_DEBUG                                       = true
    FLASK_ENV                                         = var.flask_env
    FLASK_PROPAGATE_EXCEPTIONS                        = true
    FPS                                               = 60
    JUKEBOX_CONTAINER_APP_DIR                         = "/opt/yag"
    JUKEBOX_CONTAINER_ENV_GST_DEBUG                   = "3,ximagesrc:3,webrtcsink:3,pulsesrc:4,webrtcbin:4,webrtcsrc-signaller:3,vadisplay:3,webrtcsrc-signaller:7"
    JUKEBOX_CONTAINER_STREAMD_LOADING_DURATION        = 5
    JUKEBOX_CONTAINER_STREAMD_MAX_INACTIVITY_DURATION = 1800
    JUKEBOX_CONTAINER_USER                            = "gamer"
    JUKEBOX_DOCKER_REPO_PREFIX                        = var.jukebox_docker_repo_prefix
    JUKEBOX_NODE_CLONES_ROOT_DIR                      = "/mnt/appstor"
    JUKEBOX_NODES                                     = jsonencode(var.jukebox_nodes)
    SIGNALER_HOST                                     = var.signaler_host
    SIGNALER_URI                                      = var.signaler_uri
    STUN_URI                                          = var.stun_uri
    # secrets
    SIGNALER_AUTH_TOKEN = var.signaler_auth_token
  }
}

resource "kubernetes_secret" "jukeboxsvc" {
  metadata {
    name = "jukeboxsvc-ssh-keys"
  }
  data = {
    "id_ed25519"     = "${file("${path.module}/files/secrets/${var.env}/id_ed25519")}"
    "id_ed25519.pub" = "${file("${path.module}/files/secrets/${var.env}/id_ed25519.pub")}"
  }
  type = "Opaque"
}
