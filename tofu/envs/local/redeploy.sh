#!/usr/bin/env bash

set -eux

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 MODULE"
    exit 1
fi

MODULE=$1

./update.sh
kubectl delete deployment $MODULE-deployment
minikube image load $MODULE:dev --overwrite=true --alsologtostderr
./update.sh

# kubectl rollout restart deployment istio-gw-public -n istio-gw-public
# kubectl rollout restart deployment jukeboxsvc-deployment
# kubectl rollout restart deployment webapp-deployment
# kubectl rollout restart deployment sigsvc-deployment
