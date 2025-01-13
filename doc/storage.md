Instructions below are applicable for cloud-based deployments with dedicated application storage instances (appstor).

# Appstor instance

Depending on order of execution in the openshift init script (OVH), main storage could be attached as `/dev/sdb` or 
`dev/sda`. This can go out of sync when e.g. openstack appstor instance resource is being rebuilt from tofu.

Make sure main storage is `/dev/sdb` before running the ansible init script:

    debian@appstor-instance:~$ ls -la /dev | grep sd
    brw-rw----  1 root disk      8,   0 Jul 17 18:40 sda
    brw-rw----  1 root disk      8,   1 Jul 17 18:40 sda1
    brw-rw----  1 root disk      8,  14 Jul 17 18:40 sda14
    brw-rw----  1 root disk      8,  15 Jul 17 18:40 sda15
    brw-rw----  1 root disk      8,  16 Jul 17 18:40 sdb

For this you may need to recreate "appstor_instance" and "appstor_volume_attach" resources:
comment them in /workspaces/infra/tofu/modules/ovh/appstor.tf, update tofu, then uncomment and update again.

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
4. Attach storage to instance.
5. Boot instance.
If boot fails, try to recreate instances from tofu (see above).
6. Run:

        sudo btrfs filesystem resize max /opt/yag/data/appstor

on each node after reboot.

7. update volume_size in ovh module in tofu.

# Useful commands

Get BTRFS UUID:

    sudo blkid -s UUID -o value /dev/sdb

Check beesd logs\status:

    sudo journalctl -f -u beesd@$(sudo blkid -s UUID -o value /dev/sdb)
    sudo systemctl status beesd@(sudo blkid -s UUID -o value /dev/sdb)
    
    sudo btrfs filesystem du -s --human-readable .
    
    sudo apt install btrfs-compsize
    sudo compsize /opt/yag/data/appstor
    sudo compsize /opt/yag/data/appstor/clones/0/red-comrades-save-the-galaxy/eaa1474d-6945-4991-8132-cef009b0fd58/D

lsyncd is not running on main instance (`sudo systemctl status lsyncd` shows active/exited):

    sudo systemctl stop lsyncd
    sudo systemctl start lsyncd

Mount appstor locally through NFS:

Prod NFS (K8S based):

    # sudo mkdir -p /mnt/appstor_nfs/prod/us-east-1
    ssh -L 2049:192.168.12.200:2049 -p 2207 -o ServerAliveInterval=10  infra@bastion.yag.im -N & disown
    sudo mount -t nfs -o nfsvers=4,minorversion=2,proto=tcp,fsc,nocto,port=2049 localhost: /mnt/appstor_nfs/prod/us-east-1
