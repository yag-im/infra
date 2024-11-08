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
send -- "y\r"
expect -exact "y\r
-- Enter AWS Access Key ID: "
send -- "$::env(AWS_ECR_ACCESS_KEY_ID)"
expect -exact "$::env(AWS_ECR_ACCESS_KEY_ID)"
send -- "\r"
expect -exact "\r
-- Enter AWS Secret Access Key: "
send -- "$::env(AWS_ECR_SECRET_ACCESS_KEY)"
expect -exact "$::env(AWS_ECR_SECRET_ACCESS_KEY)"
send -- "\r"
expect -exact "\r
-- (Optional) Enter AWS Session Token: "
send -- "\r"
expect -exact "\r
-- Enter AWS Region: "
send -- "$::env(AWS_ECR_REGION)"
expect -exact "$::env(AWS_ECR_REGION)"
send -- "\r"
expect -exact "\r
-- Enter 12 digit AWS Account ID (Comma separated list): "
send -- "$::env(AWS_ECR_ACCOUNT_ID)"
expect -exact "$::env(AWS_ECR_ACCOUNT_ID)"
send -- "\r"
expect -exact "\r
-- (Optional) Enter ARN of AWS role to assume: "
send -- "\r"
expect -exact "\r
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
