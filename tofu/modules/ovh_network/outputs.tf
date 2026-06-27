output "private_network_id" {
  value = ovh_cloud_project_network_private.private_network.id
}

output "private_network_name" {
  value = ovh_cloud_project_network_private.private_network.name
}

output "private_network_regions_attributes" {
  description = "regions_attributes of the private network (used to look up the per-region openstackid)"
  value       = ovh_cloud_project_network_private.private_network.regions_attributes
}

output "private_subnets" {
  description = "Subnet info aligned with var.networks"
  value = [
    for i, s in ovh_cloud_project_network_private_subnet.private_subnet : {
      id         = s.id
      ovh_region = var.networks[i].ovh_region
      gateway    = var.networks[i].gateway
    }
  ]
}

output "private_lb_subnet_id" {
  value       = ovh_cloud_project_network_private_subnet.private_subnet[0].id
  description = "Subnet ID for private load balancer"
}

output "network_ready" {
  description = "Synchronization handle — reference from downstream modules to wait for router interfaces"
  value       = terraform_data.network_ready.id
}
