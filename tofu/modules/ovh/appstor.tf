resource "openstack_compute_keypair_v2" "appstor_keypair" {
  count      = length(var.appstor.nodes)
  name       = "appstor-keypair-${count.index}"
  public_key = file(var.appstor.public_key_path)
  region     = var.appstor.nodes[count.index].ovh_region
}

# block storage volumes are triple-replicated in ovh so 1 volume per storage instance is enough
resource "openstack_blockstorage_volume_v3" "appstor_volume" {
  count       = length(var.appstor.nodes)
  name        = "appstor-volume"
  region      = var.appstor.nodes[count.index].ovh_region
  size        = var.appstor.volume_size
  volume_type = "high-speed"
}

resource "openstack_compute_instance_v2" "appstor_instance" {
  count       = length(var.appstor.nodes)
  name        = "appstor-instance"
  flavor_name = var.appstor.flavor
  image_name  = "Debian 13"
  key_pair    = openstack_compute_keypair_v2.appstor_keypair[count.index].name
  network {
    name        = ovh_cloud_project_network_private.private_network.name
    fixed_ip_v4 = var.appstor.nodes[count.index].host # make sure dhcp is enabled in the priv network settings (sic!)
  }
  network {
      name      = "Ext-Net"
  }
  region     = var.appstor.nodes[count.index].ovh_region
  depends_on = [ovh_cloud_project_network_private_subnet.private_subnet]
}

resource "openstack_compute_volume_attach_v2" "appstor_volume_attach" {
  count       = length(var.appstor.nodes)
  instance_id = openstack_compute_instance_v2.appstor_instance[count.index].id
  region      = var.appstor.nodes[count.index].ovh_region
  volume_id   = openstack_blockstorage_volume_v3.appstor_volume[count.index].id
}
