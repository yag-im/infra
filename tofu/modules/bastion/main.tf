resource "kubernetes_deployment" "bastion" {
  metadata {
    name = "bastion-deployment"
    labels = {
      app = "bastion"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "bastion"
      }
    }
    template {
      metadata {
        labels = {
          app = "bastion"
        }
      }
      spec {
        container {
          image             = var.docker_image_name
          image_pull_policy = "IfNotPresent"
          name              = "bastion"
          port {
            container_port = 22
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
              name = "bastion-cm"
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

resource "kubernetes_service" "bastion" {
  metadata {
    name      = "bastion"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "bastion"
    }
    port {
      port = 22
      name = "ssh"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "bastion" {
  metadata {
    name      = "bastion-cm"
    namespace = var.k8s_namespace
  }
  data = {
    AUTHORIZED_KEYS = "${file("${path.module}/files/authorized_keys")}"
    ED25519_KEY_PUB = "${file("${path.module}/files/secrets/${var.env}/id_ed25519.pub")}"
    # secrets
    ED25519_KEY     = "${file("${path.module}/files/secrets/${var.env}/id_ed25519")}"
  }
}
