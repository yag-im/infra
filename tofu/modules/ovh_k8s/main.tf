# Kubernetes cluster and node pool

resource "ovh_cloud_project_kube" "k8s_cluster" {
  service_name = var.project_id
  name         = "yag-k8s"
  region       = var.k8s.ovh_region
  private_network_id = [
    for r in var.private_network_regions_attributes :
    r.openstackid if r.region == var.k8s.ovh_region
  ][0]
  private_network_configuration {
    default_vrack_gateway = [
      for s in var.private_subnets :
      s.gateway if s.ovh_region == var.k8s.ovh_region
    ][0]
    private_network_routing_as_default = true
  }
  timeouts {
    create = "1h"
  }
  depends_on = [terraform_data.wait_for_network]
}

resource "ovh_cloud_project_kube_nodepool" "node_pool" {
  service_name   = var.project_id
  name           = "cluster-nodepool"
  anti_affinity  = false
  autoscale      = false
  desired_nodes  = var.k8s.desired_nodes
  flavor_name    = var.k8s.flavor
  kube_id        = ovh_cloud_project_kube.k8s_cluster.id
  max_nodes      = var.k8s.max_nodes
  min_nodes      = var.k8s.min_nodes
  monthly_billed = false
  timeouts {
    create = "1h"
  }
}

resource "terraform_data" "kubeconfig" {
  input = ovh_cloud_project_kube.k8s_cluster.kubeconfig

  provisioner "local-exec" {
    command = "printf '%s' \"$KUBECONFIG_CONTENT\" > ${var.kubeconfig_filename} && chmod 0644 ${var.kubeconfig_filename}"
    environment = {
      KUBECONFIG_CONTENT = self.input
    }
  }

  depends_on = [ovh_cloud_project_kube.k8s_cluster, ovh_cloud_project_kube_nodepool.node_pool]
}

# Local gate mirroring var.network_ready so the kube resource can depends_on it.
resource "terraform_data" "wait_for_network" {
  input = var.network_ready
}
