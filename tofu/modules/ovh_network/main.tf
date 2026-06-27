# Networking: VRack, project-level private network, per-region subnets, routers

resource "ovh_vrack_cloudproject" "vcp_attach" {
  service_name = var.vrack_id
  project_id   = var.project_id
}

resource "ovh_cloud_project_network_private" "private_network" {
  service_name = var.project_id
  name         = var.network_name
  regions      = var.networks[*]["ovh_region"]
  vlan_id      = 0
  depends_on   = [ovh_vrack_cloudproject.vcp_attach]
}

data "openstack_networking_network_v2" "ext_net" {
  count  = length(var.networks)
  name   = "Ext-Net"
  region = var.networks[count.index]["ovh_region"]
}

resource "ovh_cloud_project_network_private_subnet" "private_subnet" {
  count        = length(var.networks)
  service_name = var.project_id
  network_id   = ovh_cloud_project_network_private.private_network.id
  start        = var.networks[count.index]["start"]
  end          = var.networks[count.index]["end"]
  network      = var.networks[count.index]["network"]
  dhcp         = true # required for fixed_ip_v4 to work for cloud instances
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

# Gate resource: downstream modules depend on this to ensure router interfaces
# are fully attached before they start provisioning.
resource "terraform_data" "network_ready" {
  input = openstack_networking_router_interface_v2.private_router_interface[*].id
}
