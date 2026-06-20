# Prerequisite

K8S is up and running in respective env.

    cd /workspaces/infra/scripts

# Appstor

## Build appstor image

Provisions a VM of the specified flavor (temporarly), runs an Ansible playbook to configure it, then snapshots the 
result into a reusable machine image.

    ./build_appstor_image.sh dev us-east-1

## Add new appstor nodes

    NODE_INDEX=0 ./add_appstor.sh dev us-east-1
    NODE_INDEX=1 ./add_appstor.sh dev us-east-1
    NODE_INDEX=0 ./add_appstor.sh dev us-west-1

## Init master appstor node

Note: bastion host should be up and running in k8s for ssh connection

    ./init_appstor_master.sh dev

# Jukebox

## Build jukebox image

Provisions a VM of the specified flavor (temporarly), runs an Ansible playbook to configure it, then snapshots the 
result into a reusable machine image.

    ./build_jukebox_image.sh dev us-east-1

## Add a new jukebox node

    NODE_INDEX=0 ./add_jukebox.sh dev us-east-1

# Cleanup

## Remove node

    DELETE_VOLUME=false ./rm_node.sh dev us-east-1 xxx
