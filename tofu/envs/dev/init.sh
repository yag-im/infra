#!/usr/bin/env bash

set -eux

set -o allexport
    source .env
    source ./secrets/.env
set +o allexport
. ./secrets/openrc

read -p "WARNING! Current deployment will be destroyed. Are you sure you want to proceed, y/n? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

# without the removal below, terraform keeps refs to VirtualServices and fails to init
rm -rf .terraform || true
rm .terraform.lock.hcl || true
rm terraform.tfstate || true
# rm terraform.tfstate.backup || true

tofu init

# need to bootstrap networking and k8s barebone cluster first
tofu apply -target=module.ovh -auto-approve

# init and renew aws ecr secret key
tofu apply -target=module.aws_ecr -auto-approve
kubectl create job --from=cronjob/k8s-ecr-login-renew-cron k8s-ecr-login-renew-cron-manual-1
# check job output:
# kubectl describe job k8s-ecr-login-renew-cron-manual-1
# kubectl logs job/k8s-ecr-login-renew-cron-manual-1
# kubectl -n default describe secret $(kubectl -n default get secret | grep awsecr-cred | awk '{print $1}')

./update.sh --first-pass
