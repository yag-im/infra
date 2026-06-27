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

# need to bootstrap OVH infra (networking, k8s) before services
tofu apply -target=module.ovh_network
tofu apply -target=module.ovh_k8s

./update.sh --first-pass
