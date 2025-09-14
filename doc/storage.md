Instructions below are applicable for cloud-based deployments with dedicated application storage instances (appstor).

# Appstor instance

## init

Depending on order of execution in the openshift init script (OVH), main storage could be attached as `/dev/sdb` or 
`dev/sda`. This can go out of sync when e.g. openstack appstor instance resource is being rebuilt from tofu.

Make sure main storage is `/dev/sdb` before running the ansible init script:

    debian@appstor-instance:~$ ls -la /dev | grep sd
    brw-rw----  1 root disk      8,   0 Jul 17 18:40 sda
    brw-rw----  1 root disk      8,   1 Jul 17 18:40 sda1
    brw-rw----  1 root disk      8,  14 Jul 17 18:40 sda14
    brw-rw----  1 root disk      8,  15 Jul 17 18:40 sda15
    brw-rw----  1 root disk      8,  16 Jul 17 18:40 sdb

If order is messed up (e.g. storage is attached as sda, and system disk is sdb) then detach storage from instance in
OVH admin panel, reboot instance and reattach storage drive. It should appear as sdb then.

The try plain ssh connect from host:

    ssh -i /workspaces/infra/tofu/modules/bastion/files/secrets/dev/id_ed25519 -o ServerAliveInterval=10 -o ProxyCommand="ssh -p 2207 -W %h:%p infra@bastion.dev.yag.im" debian@192.168.13.200

Note that ProxyCommand is not using keys on the bastion host, instead they should be provided from the host machine.

Run appstor init playbook; start with replica (us-west-1) nodes, so master (us-east-1) will not fail later with `lsyncd`.

    cd /workspaces/infra/ansible

    export INFRA_ENV=dev; \
    export INFRA_USER=debian; \
    export INFRA_DC=us-west-1; \
    ansible-playbook \
        --ssh-common-args '-o ServerAliveInterval=10 -o ProxyCommand="ssh -p 2207 -W %h:%p -q infra@bastion.dev.yag.im"' \
        --user ${INFRA_USER} \
        --key-file "/workspaces/infra/tofu/modules/bastion/files/secrets/${INFRA_ENV}/id_ed25519" \
        --vault-password-file=envs/${INFRA_ENV}/.vault_pwd \
        -i envs/${INFRA_ENV}/hosts_${INFRA_DC}.yml \
        playbooks/appstor.yml

Do the same for us-east-1 appstor node.

Note: TODO: there is a bug in the ansible appstor init script, chmod 1000 is failing, so need to perform:

    chown -R 1000:1000 /opt/yag/data/appstor

manually on all nodes after init.

## devices

    /dev/sda
    /dev/sdb -> RAID-1 btrfs volume

## fstab
    
    /dev/sdb /opt/yag/data/appstor btrfs defaults 0 0

## docker (nfs server)

Binds `/opt/yag/data/appstor` into `/mnt` and:

    exporting *:/mnt/clones
    exporting *:/mnt/apps
    exporting *:/mnt/runners
    exporting *:/mnt/apps_src
    exporting *:/mnt

# jukebox node (apps runner)

## docker volume

Local dev:

    docker volume create --driver local \
        --opt type=none \
        --opt o=bind \
        --opt device=~/yag/data/ports/clones \
        appstor-vol

or cloud (NFS) mode:

    docker volume create --driver local \
        -o type=nfs \
        -o o=addr="{appstor_dc_ip},rw,nfsvers=4,minorversion=2,proto=tcp,fsc,nocto" \
        -o device=:/clones \
        appstor-vol

## fstab (deprecated, use docker volume instead)

    {appstor_dc_ip}:/clones /mnt/appstor/ nfs nfsvers=4,minorversion=2,proto=tcp,fsc,nocto 0 0

## docker (jukebox image)

Binds `{appstor-vol}/{user_id}/{app_release_slug}/{app_release_uuid}` into `/opt/yag`

# jukeboxsvc

Performs apps cloning (apps -> clones) operation by SSH-ing into appstor instance and CoW-ing app bundle
(check implementation in the [clone_app.sh](../ansible/roles/appstor/files/clone_app.sh)) script.

# Expanding appstor space

1. In OVH panel, open `Storage -> Block Storage`. Extend size of instances.
2. Detach storage from instance.
3. Shut down instance.
4. Boot instance.
5. Attach storage to instance.
If boot fails, try to recreate instances from tofu (see above).
6. Run:

        sudo btrfs filesystem resize max /opt/yag/data/appstor

on each node after reboot.

7. WARNING! update volume_size in ovh module in tofu. WARNING! Next time tofu runs, appstor will be destroyed. 
Need to re-init it using ansible init script. So skip this step, but remeber to update volume size later.
8. Check lsyncd is running on the master node (US-EAST) (see FAQ below).

# Q&A and useful commands

Q: How to get BTRFS UUID?

A:

    sudo blkid -s UUID -o value /dev/sdb

Q: How to check beesd logs\status?

A:
    sudo journalctl -f -u beesd@$(sudo blkid -s UUID -o value /dev/sdb)
    sudo systemctl status beesd@$(sudo blkid -s UUID -o value /dev/sdb)
    
    sudo btrfs filesystem du -s --human-readable /opt/yag/data/appstor
    
    sudo apt install btrfs-compsize
    sudo compsize /opt/yag/data/appstor
    sudo compsize /opt/yag/data/appstor/clones/0/red-comrades-save-the-galaxy/eaa1474d-6945-4991-8132-cef009b0fd58/D

Q: lsyncd is not running on the main instance (US-EAST).

A: Check if lsycnd is running:

    sudo systemctl status lsyncd

Restart lsyncd service:

    sudo systemctl restart lsyncd

Q: How to mount appstor locally through NFS?

A: For prod NFS (K8S based):

    # sudo mkdir -p /mnt/appstor_nfs/prod/us-east-1
    ssh -L 2049:192.168.12.200:2049 -p 2207 -o ServerAliveInterval=10  infra@bastion.yag.im -N & disown
    sudo mount -t nfs -o nfsvers=4,minorversion=2,proto=tcp,fsc,nocto,port=2049 localhost: /mnt/appstor_nfs/prod/us-east-1

Q: CPU upgrade

A: When upgrading a CPU, make sure to review all DOSBox configurations with "cycles: fixed XXX", as the values may 
become inaccurate. Also, for qemu - update -cpu model parameter.
