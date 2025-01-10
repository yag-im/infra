# Local k8s cluster setup

The local configuration consists of a group of jukebox cluster nodes operating within VirtualBox VMs (vagrant), with the 
remaining services running in a minikube cluster. Additionally, you have the option to access all services from VSCodes' 
devcontainers.

Modes of operation:

- All resources are running as devcontainers. Devcontainers can see each other by names or through the localhost 
(--network host mode);
- All resources are running as pods in a minikube cluster. Pods can see each other by using k8s internal names;
- Mix of devcontainers and minikube services. Devcontainers can access minikube nodes throught the istio gateways 
(must be defined in /etc/hosts on localhost; /etc/hosts should be mounted inside a devcontainer). 
Minikube nodes can access devcontainers through the localhost (host.minikube.internal).

## Jukebox cluster [VirtualBox VMs]

### Provision VMs (run on the dev host)

We should use "virtualbox" provider as we need to install docker (for apps runners) inside VMs.

Install deps:

    sudo apt install vagrant
    vagrant plugin install vagrant-hosts

`vagrant-hosts` plugin is required so VMs can see each other by FQDNs.

Execute all further commands from a directory containing the Vagrantfile:

    cd infra/ansible/envs/local/vagrant

Make sure appstor disk (/dev/sdb) is mounted to the physical host. Double check disk sizes in Vagrantfile and drive 
device below.

    sudo mkdir /mnt/vagrant_disk
    sudo mount /dev/sdb /mnt/vagrant_disk

Build and run virtual machines (check Vagrantfile for details):
    
    vagrant up

This should bring up 2 virtual clusters: in the us-west-1 and eu-central-1 virtual zones, each having a dedicated 
appstor instance.

If deployment fails (this happens quite often) destroy VMs and try again:

    vagrant destroy -f
    vagrant up

Check provisioned VMs:

    vagrant ssh jukebox1.us-west-1.yag.vm
    ssh -i ~/.vagrant.d/insecure_private_keys/vagrant.key.rsa vagrant@127.0.0.1 -p 2202

ssh to the vagrant VMs works only through the 127.0.0.1 custom ports. 
A generation of a custom ssh config is required so ansible can ssh into VM nodes (when running from a devcontainer):

    cd infra/ansible/envs/local/vagrant
    vagrant ssh-config > ssh.config
    sed -i 's/robert/vscode/g' ssh.config

The last line (sed) is required for running ansible from a devcontainer environment.

Make sure you've added all cluster nodes into /etc/hosts on the host machine so they become accessible from jukeboxsvcs'
devcontainer under the `host.docker.internal` domain (see /etc/hosts section below).

### Init VMs (ansible-driven, run inside VSCodes' devcontainer)

Before proceeding - update `otelcol_gw_ip` in `ansible/envs/local/group_vars/all/env_all.yml`.

#### Init app storages (appstor)

These should be setup first so they can be mounted by jukebox nodes.

Disks mouning schema is described below:

    On the host:
        /dev/sdb device (dedicated physical HDD) mounted as /mnt/vagrant_disk
        /mnt/vagrant_disk: contains vdi images attached as SATA devices to appstor VMs
    In appstor VMs: 
        BTRFS (RAID1) built on top of attached SATA devices, mounted as: /opt/yag/data/appstor
        NFS server (docker container) running with /opt/yag/data/appstor mounted as /mnt inside the container and exposing:
            /mnt/apps
            /mnt/apps_src
            /mnt/clones
            /mnt/runners
    
    Jukebox nodes should mount storages above by NFS.

Run appstor init playbook; start with replica (eu-central-1) nodes, so master (us-west-1) will not fail later to 
`lsyncd` to them.

    cd /workspaces/infra/ansible

    export INFRA_ENV=local; \
    export INFRA_USER=vagrant; \
    export INFRA_DC=eu-central-1; \
    ansible-playbook \
        --ssh-common-args "-F /workspaces/infra/ansible/envs/local/vagrant/ssh.config" \
        --user ${INFRA_USER} \
        --key-file "~/.vagrant.d/insecure_private_keys/vagrant.key.ed25519" \
        --vault-password-file=envs/${INFRA_ENV}/.vault_pwd \
        -i envs/${INFRA_ENV}/hosts_${INFRA_DC}.yml \
        playbooks/appstor.yml

Repeat the same with master region: `INFRA_DC=us-west-1`.

On the host machine:

    docker volume create --driver local \
        -o type=nfs \
        -o o=addr="127.0.0.1,rw,nfsvers=4,minorversion=2,proto=tcp,fsc,nocto,port=12049" \
        -o device=:/clones \
        appstor-vol-us-west-1
    
    docker volume create --driver local \
        -o type=nfs \
        -o o=addr="127.0.0.1,rw,nfsvers=4,minorversion=2,proto=tcp,fsc,nocto,port=12050" \
        -o device=:/clones \
        appstor-vol-eu-central-1

#### Init cluster (jukebox) nodes

Run ansible cluster init playbook:

    cd /workspaces/infra/ansible

    export INFRA_ENV=local; \
    export INFRA_USER=vagrant; \
    export INFRA_DC=us-west-1; \
    ansible-playbook \
        --ssh-common-args "-F /workspaces/infra/ansible/envs/local/vagrant/ssh.config" \
        --user ${INFRA_USER} \
        --key-file "~/.vagrant.d/insecure_private_keys/vagrant.key.ed25519" \
        --vault-password-file=envs/${INFRA_ENV}/.vault_pwd \
        -i envs/${INFRA_ENV}/hosts_${INFRA_DC}.yml \
        playbooks/jukebox_cluster.yml

Repeat the same with `INFRA_DC=eu-central-1`.

#### Pre-populate docker images cache

Run POST http://localhost:80/cluster/pull_image from jukeboxsvcs' tests/requests.http file.

#### Validate cluster setup

From jukebox node VM:

    vagrant ssh jukebox2.us-west-1.yag.vm
    curl -v http://jukebox1.us-west-1.yag.vm:2375/v1.43/images/json
    curl -v http://jukebox1.eu-central-1.yag.vm:2375/v1.43/images/json

From dev host (note ports difference):

    curl -v http://jukebox1.us-west-1.yag.vm:12375/v1.43/images/json
    curl -v http://jukebox1.eu-central-1.yag.vm:12385/v1.43/images/json

From jukeboxsvcs' devcontainer (note hosts difference):

    curl -v http://host.docker.internal:12375/v1.43/images/json
    curl -v http://host.docker.internal:12385/v1.43/images/json

## minikube (the rest of IaC)

### Install deps

#### kubectl

    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

#### minikube

    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
    sudo dpkg -i minikube_latest_amd64.deb

#### helm

    https://helm.sh/docs/intro/install/

#### tofu

    https://opentofu.org/docs/intro/install/deb/

### Bootstrap minikube cluster

Make sure you've created all secrets beforehand (see tofu/secrets.txt).

Run a bootstrap script:

    cd infra/tofu/envs/local
    ./init.sh

If istio gateways fail to start, run:
    
    ps fax | grep "minikube tunnel"

and if it's not running then:

    minikube tunnel & disown

as it might be crashed during init.sh execution.

#### Discover bootstrap errors

    kubectl describe pods
    kubectl describe pod landing-deployment-7874ccc9dd-6tvln
    kubectl describe pod -n istio-gw-public istio-gw-public-7c9c597ccb-2z7dh

    or

    minikube dashboard

#### Redeploy

    ./redeploy.sh MODULE
    
#### Get services

    kubectl get svc

#### Get pods

    kubectl get pod -A
    kubectl describe nodes

# Networking changes

Obtain public and private gateway addresses in the minikube cluster using:

    kubectl get svc -n istio-gw-public istio-gw-public
    kubectl get svc -n istio-gw-private istio-gw-private

/etc/hosts:

    # yag local dev setup
    # vagrant vms
    127.0.0.1 jukebox1.us-west-1.yag.vm jukebox2.us-west-1.yag.vm
    127.0.0.1 jukebox1.eu-central-1.yag.vm jukebox2.eu-central-1.yag.vm
    # devcontainers
    127.0.0.1 appsvc.yag.dc jukeboxsvc.yag.dc portsvc.yag.dc sessionsvc.yag.dc sigsvc.yag.dc sqldb.yag.dc webapi.yag.dc yag.dc
    # minikube: istio public
    10.x.x.x bastion.yag.mk grafana.yag.mk yag.mk
    # minikube: istio private
    10.x.x.x otelcol-gw.yag.mk

Update `signaler_uri` in jukeboxs' config (infra/tofu/envs/{ENV}/main.tf). Set it to the ext IP of the public gateway.
Then:

    ./redeploy.sh jukeboxsvc

Update `otelcol_gw_ip` in ansible/envs/{ENV}/group_vars/all/env_all.yml
(requires ansible update)
