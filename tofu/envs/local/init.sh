#!/usr/bin/env bash

set -e

#pkill -9 kubectl
#pkill -9 minikube

set -o allexport
    source ./.env
    source ./secrets.env
set +o allexport

/usr/bin/expect -c '
set timeout -1
spawn ./__init.sh
match_max 100000
expect -exact "\r
Do you want to enable AWS Elastic Container Registry? \[y/n\]: "
send -- "n\r"
\r
Do you want to enable Google Container Registry? \[y/n\]: "
send -- "n\r"
expect -exact "n\r
\r
Do you want to enable Docker Registry? \[y/n\]: "
send -- "n\r"
expect -exact "n\r
\r
Do you want to enable Azure Container Registry? \[y/n\]: "
send -- "n\r"
expect eof
'
