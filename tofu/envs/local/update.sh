#!/usr/bin/env bash

set -o allexport
    source ./.env
    source ./secret.env
set +o allexport

# we can't create VirtualServices on the very first pass (when called from __init.sh)
if [[ "$1" == "--first-pass" ]]; then
    tofu apply -auto-approve
fi

tofu apply -var "create_istio_vs=true" -auto-approve
