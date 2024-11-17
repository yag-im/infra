# Managed K8S

API console: https://api.us.ovhcloud.com/console/#/auth/time~GET

## Prerequisites

Tutorial: https://help.ovhcloud.com/csm/en-public-cloud-kubernetes-vrack-custom-gateway?id=kb_article_view&sysparm_article=KB0050040

Create a new public cloud project from:

    https://us.ovhcloud.com/manager/#/public-cloud/pci/projects/new

Use `dev.yag.im` as a project name.

Wait for about 2 minutes while the new project is being provisioned.

- In `Left Menu` -> `Quota and Regions` section:
    - Add more regions;
    - Request quotas increase for all regions.

- From `Users&Roles`:
    - create a new user `infra` with `Administrator` permissions;
    - download `openrc` file (select `US-EAST-VA-1` region on download);
        - replace `OS_PASSWORD` in downloaded `openrc` file with value generated on `Users&Roles` screen (`Generate a password` user menu option);
        - remove echo "Enter your password" and read from stdin (into OS_PASSWORD) part.

- Generate parameters for `secrets/.env` from https://api.us.ovhcloud.com/createToken/ (common for dev/prod, so do it once).

Update `.env` and `openrc` in /workspaces/infra/tofu/envs/dev/secrets.

## Secrets

Init AWS secrets storage: execute commands from tofu/secrets.txt, e.g.

    export AWS_PROFILE=yag-dev
    export AWS_REGION=us-east-1
    aws ssm put-parameter --profile "$AWS_PROFILE" --region "$AWS_REGION" --name "/otel/grafana_admin_password" --value "********" --type SecureString
    ...

## Cloud init

Checklist:

- Make sure no resources are used on the `Quotas and Regions` page.
- Make sure `dev.yag.im` is NOT part of vRack (right tab on the vRack page), it will be attached later from the tofu init script.
- Disable `httpsRedirect` in `istio` module, letsencrypt requires an unsecure HTTP connection to validate certs.

    cd /workspaces/infra/tofu/envs/dev
    ./init.sh

For further updates use:

    ./update.sh

### Troubleshooting

Problem: os_keypairs creation failing due to duplicate.

This may happen if init failed in the middle, keypairs deletion is not handled properly by openstack in terraform.

You need to delete keypairs manually:

1. Install openstackclient: 

    pip install python-openstackclient

2. List and delete keypair:

    openstack keypair list
    openstack keypair delete xxx

You need to switch between regions, for this change `OS_REGION_NAME` in secrets/openrc and re-export env vars:

    . secrets/openrc

## Config updates

### DNS

    kubectl get svc -n istio-gw-public istio-gw-public
    Upd: /workspaces/infra/aws/aws/conf.py: PUBLIC_IP
    cd /workspaces/infra/aws
    source .venv/bin/activate
    cdk deploy DnsStack --profile yag-dev -c env=dev

## Init appstors

First try plain ssh connect from host:

    ssh -i /workspaces/infra/tofu/modules/bastion/files/secrets/dev/id_ed25519 -o ProxyCommand="ssh -p 2207 -W %h:%p infra@bastion.dev.yag.im" debian@192.168.13.200

Note that ProxyCommand is not using keys on the bastion host, instead they should be provided from the host machine.

Run appstor init playbook; start with replica (us-west-1) nodes, so master (us-east-1) will not fail later with `lsyncd`.

    cd /workspaces/infra/ansible

    export INFRA_ENV=dev; \
    export INFRA_USER=debian; \
    export INFRA_DC=us-west-1; \
    ansible-playbook \
        --ssh-common-args '-o ProxyCommand="ssh -p 2207 -W %h:%p -q infra@bastion.dev.yag.im"' \
        --user ${INFRA_USER} \
        --key-file "/workspaces/infra/tofu/modules/bastion/files/secrets/${INFRA_ENV}/id_ed25519" \
        --vault-password-file=envs/${INFRA_ENV}/.vault_pwd \
        -i envs/${INFRA_ENV}/hosts_${INFRA_DC}.yml \
        playbooks/appstor.yml

Do the same for us-east-1 appstor node.

Note: TODO: there is a bug in the ansible appstor init script, chmod 1000 is failing, so need to perform:

    chown -R 1000:1000 /opt/yag/data/appstor

manually on all nodes after init.

## k8s dashboard

Retrieve access token:

    cd /workspaces/infra/tofu/envs/dev
    kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep dashboard-user-token | awk '{print $1}')

Create proxy locally:
    
    kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443 & disown

Open in browser:

    https://localhost:8443

## Cleanup

    tofu destroy

    or

    remove k8s cluster from OVH UI and all network inventory (routers, networks) from Horizon UI 
    (Horizon link is available from the OVH Cloud Project menu).

## Connect to k8s node

    kubectl get nodes
    kubectl debug node/cluster-nodepool-node-1bef9f -it --image=ubuntu

## Connect to bastion

    ssh -o ServerAliveInterval=60 -p 2207 infra@bastion.dev.yag.im

Then connect to appstor from bastion: 

    ssh debian@192.168.12.200

# Jukebox cluster (dedicated servers with custom iGPUs)

Order dedicated servers in multiple regions qualifying minimal requirements below:

    - iGPU
    - 32GB of RAM

WARNING: not every MB with Xeon XXXXG CPU supports iGPU.

    sudo dmidecode | grep -A4 'Base Board Information'
        
        Asrock E3C246D4U2-2T: supports
        Asus P11C-M-10G-2T Series: doesn't support

## BIOS settings

In order to configure server for maximum performance make following changes:

    Performance Tuning:
        Core Optimizer: Enabled
        Engine Boost: Level3(max)

Disable all kind of CPU throttling options (this is mandatory and improves performance significantly):

    Advanced -> CPU configuration
        Intel Hyper-Threading Technology: Disabled
        CPU C State Support: Disabled
        Intel SpeedStep: Disabled
        CPU Termal Throttling: Disabled

In order to see iGPU devices at /dev/dri you need to disable IOMMU:

    Advanced -> CPU configuration -> Intel VMX Virtualization Technology: Disable
    Chipset -> System agent -> VT-d: Disabled (sometimes this option reside in `Advanced -> CPU configuration`)
    Update /etc/default/grub: remove "nomodeset"
        sudo update-grub
        sudo reboot

## OS install

Request Debian (Bookworm) installation.

Use `jukeboxXX` as hostname.

Provide infras' (/workspaces/infra/tofu/modules/bastion/files/secrets/dev/id_ed25519.pub) ssh key on installation.

## Bootstrap

    ssh -i /workspaces/infra/tofu/modules/bastion/files/secrets/dev/id_ed25519 debian@51.81.208.83

    sudo vim /etc/netplan/50-cloud-init.yaml

        eno2:
            dhcp4: false
            addresses:
            - 192.168.13.2/16

    sudo netplan apply

Move instance to OVH -> vRack so it's assessible via private network for next step (ansible init).

## Init

    cd /workspaces/infra/ansible

    export INFRA_ENV=dev; \
    export INFRA_USER=debian; \
    export INFRA_DC=us-west-1; \
    ansible-playbook \
        --ssh-common-args '-o ProxyCommand="ssh -p 2207 -W %h:%p -q infra@bastion.dev.yag.im"' \
        --user ${INFRA_USER} \
        --key-file "/workspaces/infra/tofu/modules/bastion/files/secrets/${INFRA_ENV}/id_ed25519" \
        --vault-password-file=envs/${INFRA_ENV}/.vault_pwd \
        -i envs/${INFRA_ENV}/hosts_${INFRA_DC}.yml \
        playbooks/jukebox_cluster.yml

Repeat the same for other regions (us-east-1 etc).
