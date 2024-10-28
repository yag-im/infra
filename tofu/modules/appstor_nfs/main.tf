resource "helm_release" "csi-driver-nfs" {
  name       = "csi-driver-nfs"
  namespace  = "kube-system"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart      = "csi-driver-nfs"
  version    = "4.6.0"
}

resource "kubernetes_persistent_volume" "appstor_pv_nfs" {
  count = length(var.servers)
  metadata {
    annotations = {
      "pv.kubernetes.io/provisioned-by" = "nfs.csi.k8s.io"
    }
    labels = {
      app = "appstor"
      region = var.servers[count.index].region
    }
    name = "appstor-pv-${count.index}"
  }
  spec {
    access_modes = ["ReadWriteMany"]
    capacity = {
        storage = "1Mi"
    }
    mount_options = ["nfsvers=4.2", "rw", "relatime", "hard", "async", "fsc", "nocto", "proto=tcp", "rsize=1048576", "wsize=1048576", "port=${var.servers[count.index].port}"]
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      csi {
        driver = "nfs.csi.k8s.io"
        volume_handle = "${var.servers[count.index].host}/${var.servers[count.index].region}"
        volume_attributes = {
          server = var.servers[count.index].host
          share = "/"
        }
      }      
    }    
    storage_class_name = "nfs-csi"
  }
}

resource "kubernetes_persistent_volume_claim" "appstor_pvc_nfs" {
  count = length(var.servers)
  metadata {
    name = "appstor-pvc-${count.index}"
    labels = {
      region = var.servers[count.index].region
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "1Mi"
      }
    }
    storage_class_name = "nfs-csi"
    volume_name = "appstor-pv-${count.index}"
  }
}
