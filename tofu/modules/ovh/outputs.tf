output "private_lb_subnet_id" {
  value = ovh_cloud_project_network_private_subnet.private_subnet[0].id
  description = "Subnet ID for private load balancer"
}
