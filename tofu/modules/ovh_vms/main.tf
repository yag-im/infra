locals {
  jukebox_nodes_map = {
    for entry in flatten([
      for r in var.jukebox_nodes : [
        for i in range(r.count) : {
          key         = "jukebox${i}.${r.region}"
          name        = "jukebox${i}-${r.region}"
          ip          = "${r.base_ip_prefix}.${r.base_ip_octet + i}"
          docker_port = r.docker_port
          ssh_port    = r.ssh_port
        }
      ]
    ]) : entry.key => entry
  }

  appstor_nodes_map = {
    for entry in flatten([
      for r in var.appstor_nodes : [
        for i in range(r.count) : {
          key      = "appstor${i}.${r.region}"
          name     = "appstor${i}-${r.region}"
          ip       = "${r.base_ip_prefix}.${r.base_ip_octet + i}"
          ssh_port = r.ssh_port
          nfs_port = r.nfs_port
        }
      ]
    ]) : entry.key => entry
  }
}

resource "kubernetes_service" "jukebox_node" {
  for_each = local.jukebox_nodes_map

  metadata {
    name      = each.value.name
    namespace = "default"
  }
  spec {
    port {
      name = "docker"
      port = each.value.docker_port
    }
    port {
      name = "ssh"
      port = each.value.ssh_port
    }
  }
}

resource "kubernetes_endpoints" "jukebox_node" {
  for_each = local.jukebox_nodes_map

  metadata {
    name      = each.value.name
    namespace = "default"
  }
  subset {
    address {
      ip = each.value.ip
    }
    port {
      name = "docker"
      port = each.value.docker_port
    }
    port {
      name = "ssh"
      port = each.value.ssh_port
    }
  }
}

resource "kubernetes_service" "appstor_node" {
  for_each = local.appstor_nodes_map

  metadata {
    name      = each.value.name
    namespace = "default"
  }
  spec {
    port {
      name = "ssh"
      port = each.value.ssh_port
    }
    port {
      name = "nfs"
      port = each.value.nfs_port
    }
  }
}

resource "kubernetes_endpoints" "appstor_node" {
  for_each = local.appstor_nodes_map

  metadata {
    name      = each.value.name
    namespace = "default"
  }
  subset {
    address {
      ip = each.value.ip
    }
    port {
      name = "ssh"
      port = each.value.ssh_port
    }
    port {
      name = "nfs"
      port = each.value.nfs_port
    }
  }
}
