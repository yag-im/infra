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

./update.sh --first-pass
