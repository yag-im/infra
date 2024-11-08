Configs locations:

    ansible/envs/000_global_vars.yml               - global ansible config
    ansible/envs/${ENV}/group_vars/all/env_all.yml - env-specific ansible config
    tofu/envs/${ENV}/.env                          - used to bootstrap a k8s cluster
    tofu/envs/${ENV}/variables.tf                  - k8s modules config parameters

Secrets locations (make sure they're not part of any source trees):

    ansible/envs/${ENV}/group_vars/all/vault
    ansible/envs/${ENV}/.vault_pwd                 - used from ansible playbooks
    tofu/modules/bastion/files/secrets             - infra user keys
    tofu/envs/${ENV}/secrets.env                   - used to bootstrap a k8s cluster (minikube)
    tofu/envs/${ENV}/secrets                       - used to bootstrap a k8s cluster (dev, prod)
    tofu/secrets.txt                               - used from k8s cluster, contains AWS SSM parameters init script

SSH keys:

    ssh-keygen -t ed25519 -f id_ed25519 -q -N "" -C "infra@yag.im"
