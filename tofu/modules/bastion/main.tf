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
          image             = var.docker_image
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
          volume_mount {
            name       = "bastion-ssh-keys-volume"
            mount_path = "/home/infra/.ssh/authorized_keys"
            sub_path   = "authorized_keys"
          }
          volume_mount {
            name       = "bastion-ssh-keys-volume"
            mount_path = "/home/infra/.ssh/id_ed25519"
            sub_path   = "id_ed25519"
          }
          volume_mount {
            name       = "bastion-ssh-keys-volume"
            mount_path = "/home/infra/.ssh/id_ed25519.pub"
            sub_path   = "id_ed25519.pub"
          }
        }
        volume {
          name = "bastion-ssh-keys-volume"
          secret {
            secret_name  = "bastion-ssh-keys"
            default_mode = "0600"
          }
        }
        security_context {
          fs_group = 1000
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

resource "kubernetes_secret" "bastion" {
  metadata {
    name = "bastion-ssh-keys"
  }
  data = {
    "id_ed25519"      = "${file("${path.module}/files/secrets/${var.env}/id_ed25519")}"
    "id_ed25519.pub"  = "${file("${path.module}/files/secrets/${var.env}/id_ed25519.pub")}"
    "authorized_keys" = "${file("${path.module}/files/secrets/authorized_keys")}"
  }
  type = "Opaque"
}
