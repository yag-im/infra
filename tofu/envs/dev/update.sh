#!/usr/bin/env bash

# we can't create VirtualServices on the very first pass (when called from init.sh)
if [[ "$1" == "--first-pass" ]]; then
    tofu apply -auto-approve
else
# direct ./update.sh launch - need to set env vars
    set -o allexport
    source ./secrets/.env
    set +o allexport
    . ./secrets/openrc
fi

tofu apply -var "create_istio_vs=true"
