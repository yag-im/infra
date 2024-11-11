resource "ovh_vrack_cloudproject" "vcp_attach" {
  service_name = var.vrack_id
  project_id   = var.project_id
}

data "openstack_networking_network_v2" "ext_net" {
  count  = length(var.networks)
  name   = "Ext-Net"
  region = var.networks[count.index]["ovh_region"]
}

resource "ovh_cloud_project_network_private" "private_network" {
  service_name = var.project_id
  name         = "yag-pn"
  regions      = var.networks[*]["ovh_region"]
  vlan_id      = 0
  depends_on   = [ovh_vrack_cloudproject.vcp_attach]
}

resource "ovh_cloud_project_network_private_subnet" "private_subnet" {
  count        = length(var.networks)
  service_name = var.project_id
  network_id   = ovh_cloud_project_network_private.private_network.id
  start        = var.networks[count.index]["start"]
  end          = var.networks[count.index]["end"]
  network      = var.networks[count.index]["network"]
  dhcp         = true # this needs to be true for fixed_ip_v4 to work for cloud instances (https://us.ovhcloud.com/manager/#/dedicated/ticket/410831)
  region       = var.networks[count.index]["ovh_region"]
  no_gateway   = false
}

resource "openstack_networking_router_v2" "private_router" {
  count               = length(var.networks)
  name                = "yag-pn-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.ext_net[count.index].id
  region              = var.networks[count.index]["ovh_region"]
}

resource "openstack_networking_router_interface_v2" "private_router_interface" {
  count     = length(var.networks)
  router_id = openstack_networking_router_v2.private_router[count.index].id
  region    = var.networks[count.index]["ovh_region"]
  subnet_id = ovh_cloud_project_network_private_subnet.private_subnet[count.index].id
}

resource "ovh_cloud_project_kube" "k8s_cluster" {
  service_name       = var.project_id
  name               = "yag-k8s"
  region             = var.k8s.ovh_region
  private_network_id = [for region in ovh_cloud_project_network_private.private_network.regions_attributes : region.openstackid if region.region == var.k8s.ovh_region][0]
  private_network_configuration {
    default_vrack_gateway              = [for network in var.networks : network.gateway if network.ovh_region == var.k8s.ovh_region][0]
    private_network_routing_as_default = true
  }
  depends_on = [openstack_networking_router_interface_v2.private_router_interface]
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

resource "local_sensitive_file" "kubeconfig" {
  content         = ovh_cloud_project_kube.k8s_cluster.kubeconfig
  filename        = "kubeconfig"
  file_permission = "0644"
  depends_on      = [ovh_cloud_project_kube.k8s_cluster, ovh_cloud_project_kube_nodepool.node_pool]
}
