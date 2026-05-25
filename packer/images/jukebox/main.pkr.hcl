locals {
  # Derive output image name from gpu_vendor when not explicitly overridden.
  image_output_name = var.image_output_name != "" ? var.image_output_name : (
    var.gpu_vendor == "nvidia" ? "debian13-jukebox-gpu-nvidia" : "debian13-jukebox-cpu"
  )
}

source "openstack" "ovh-debian13" {
  source_image_name = var.image_name
  image_name        = local.image_output_name
  instance_name     = "test-packer-${uuidv4()}"
  flavor            = var.flavor
  ssh_username      = "debian"
  ssh_ip_version    = "4" # ipv6 is not supported
  networks          = [var.network]
  # optional but helps stability
  ssh_timeout = "20m"
}

build {
  sources = ["source.openstack.ovh-debian13"]

  provisioner "ansible" {
    playbook_file = "${path.root}/../../../ansible/playbooks/jukebox_cluster.yml"
    user          = "debian"
    groups        = ["jukebox_cluster"]
    use_proxy     = false
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${path.root}/../../../ansible/ansible.cfg",
      "ANSIBLE_HOST_KEY_CHECKING=False",
    ]
    extra_arguments = [
      "--extra-vars", "@${path.root}/../../../ansible/envs/${var.infra_env}/group_vars/all/000_global_vars.yml",
      "--extra-vars", "@${path.root}/../../../ansible/envs/${var.infra_env}/group_vars/all/env_all.yml",
      "--extra-vars", "jukebox_cluster_stage=bake",
      "--extra-vars", "jukebox_cluster_gpu_vendor=${var.gpu_vendor}",
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
    ]
  }

  # Strip per-instance identity so each cloud node generates its own at first boot.
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs --seed || true",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo rm -f /var/lib/jukebox/.bootstrapped",
    ]
  }
}
