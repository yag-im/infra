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

tofu destroy
