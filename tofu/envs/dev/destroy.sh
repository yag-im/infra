#!/usr/bin/env bash

set -eux

set -o allexport
    source .env
    source ./secrets/.env
set +o allexport
. ./secrets/openrc

tofu destroy
