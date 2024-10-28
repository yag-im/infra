#!/usr/bin/env bash

set -eux

# without the removal below, terraform keeps refs to VirtualServices and fails to init
rm -rf .terraform || true
rm .terraform.lock.hcl || true
rm terraform.tfstate || true
# rm terraform.tfstate.backup || true

tofu init # --upgrade

minikube delete
# memory and cpu settings are per node
minikube start --memory=4096 --cpus=2 --nodes=3
minikube addons configure registry-creds
minikube addons enable registry-creds
# default host-path volume provisioner doesn’t support multi-node clusters
minikube addons enable csi-hostpath-driver
minikube addons disable storage-provisioner
minikube addons disable default-storageclass
kubectl patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
minikube tunnel & disown

# TODO: awaiting creds to be created, means "kubectl get secrets" has "awsecr-cred" in the output
# sleep 60

minikube image load appsvc:dev --overwrite=true
minikube image load infra.bastion:dev --overwrite=true
minikube image load jobs:dev --overwrite=true
minikube image load jukeboxsvc:dev --overwrite=true
minikube image load mcc:dev --overwrite=true
minikube image load portsvc:dev --overwrite=true
minikube image load sessionsvc:dev --overwrite=true
minikube image load sqldb:dev --overwrite=true
minikube image load webapp:dev --overwrite=true
minikube image load webrtc.sigsvc:dev --overwrite=true
minikube image load yagsvc:dev --overwrite=true

./update.sh --first-pass

# https://github.com/prometheus-operator/kube-prometheus?tab=readme-ov-file#minikube
minikube addons disable metrics-server
