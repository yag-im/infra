# bastion shell

    ssh -o ServerAliveInterval=60 -p 2207 infra@bastion.yag.im

# appstor shell

    ssh -i /workspaces/infra/tofu/modules/bastion/files/secrets/prod/id_ed25519 -o ServerAliveInterval=60 -o ProxyCommand="ssh -o ServerAliveInterval=60 -p 2207 -W %h:%p infra@bastion.yag.im" debian@192.168.12.200

# jukebox shell

    ssh -i /workspaces/infra/tofu/modules/bastion/files/secrets/prod/id_ed25519 -o ServerAliveInterval=60 -o ProxyCommand="ssh -o ServerAliveInterval=60 -p 2207 -W %h:%p infra@bastion.yag.im" debian@192.168.12.2

# init appstor:

Init replicas (west, ...) first, then master (east):

    cd /workspaces/infra/ansible

    export INFRA_ENV=prod; \
    export INFRA_USER=debian; \
    export INFRA_DC=us-west-1; \
    ansible-playbook \
        --ssh-common-args '-o ProxyCommand="ssh -p 2207 -W %h:%p -q infra@bastion.yag.im"' \
        --user ${INFRA_USER} \
        --key-file "/workspaces/infra/tofu/modules/bastion/files/secrets/prod/id_ed25519" \
        --vault-password-file=envs/${INFRA_ENV}/.vault_pwd \
        -i envs/${INFRA_ENV}/hosts_${INFRA_DC}.yml \
        playbooks/appstor.yml

# init jukebox nodes:

    export INFRA_ENV=prod; \
    export INFRA_USER=debian; \
    export INFRA_DC=us-west-1; \
    ansible-playbook \
        --ssh-common-args '-o ProxyCommand="ssh -p 2207 -W %h:%p -q infra@bastion.yag.im"' \
        --user ${INFRA_USER} \
        --key-file "/workspaces/infra/tofu/modules/bastion/files/secrets/${INFRA_ENV}/id_ed25519" \
        --vault-password-file=envs/${INFRA_ENV}/.vault_pwd \
        -i envs/${INFRA_ENV}/hosts_${INFRA_DC}.yml \
        playbooks/jukebox_cluster.yml

# rsync file remotely

    rsync -avz -e "ssh -i /workspaces/infra/tofu/modules/bastion/files/secrets/prod/id_ed25519 -o ProxyCommand='ssh -p 2207 -W %h:%p infra@bastion.yag.im'" /tmp/aaa debian@192.168.12.200:/tmp

# copy remote file

    rsync -avz -e "ssh -i /workspaces/infra/tofu/modules/bastion/files/secrets/prod/id_ed25519 -o ProxyCommand='ssh -p 2207 -W %h:%p infra@bastion.yag.im'" debian@192.168.12.200:/opt/yag/data/appstor/apps/teenagent/3a0921b0-545e-42bd-9479-4f4329d1e8b3/C/TEENAGNT/SOUND.SET /tmp
