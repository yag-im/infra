#!/usr/bin/env bash

set -o allexport
source ./secrets/.env
set +o allexport
. ./secrets/openrc

tofu destroy
