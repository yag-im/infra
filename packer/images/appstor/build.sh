#!/usr/bin/env bash
# Usage:
#   ./build.sh [INFRA_ENV [CLUSTER_REGION]]
#
# Env overrides (take precedence over positional args):
#   INFRA_ENV      (default: dev)
#   CLUSTER_REGION (default: us-east-1)
#   FLAVOR, IMAGE_NAME, OPENRC
set -euo pipefail

INFRA_ENV="${INFRA_ENV:-${1:-dev}}"

case "$INFRA_ENV" in
    dev|prod) ;;
    *)
        echo "INFRA_ENV must be 'dev' or 'prod', got: $INFRA_ENV" >&2
        exit 1
        ;;
esac

CLUSTER_REGION="${CLUSTER_REGION:-${2:-us-east-1}}"
case "$CLUSTER_REGION" in
    us-east-1|us-west-1) ;;
    *)
        echo "CLUSTER_REGION must be 'us-east-1' or 'us-west-1', got: $CLUSTER_REGION" >&2
        exit 1
        ;;
esac

FLAVOR="${FLAVOR:-b3-8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENRC="${OPENRC:-/workspaces/infra/tofu/envs/${INFRA_ENV}/secrets/openrc}"

if [[ ! -f "$OPENRC" ]]; then
    echo "openrc not found: $OPENRC" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$OPENRC"
# override OS_REGION_NAME based on CLUSTER_REGION
case "$CLUSTER_REGION" in
    us-east-1) export OS_REGION_NAME="US-EAST-VA-1" ;;
    us-west-1) export OS_REGION_NAME="US-WEST-OR-1" ;;
esac

cd "$SCRIPT_DIR"

packer version
packer init .
packer validate -var "infra_env=${INFRA_ENV}" -var "flavor=${FLAVOR}" .

export PACKER_LOG=1
export PACKER_LOG_PATH=./packer.log

NETWORK_ID="$(openstack network show Ext-Net -f value -c id)"

IMAGE_NAME="${IMAGE_NAME:-debian13-appstor}"
echo "Deleting any existing images named '${IMAGE_NAME}'..."
for img_id in $(openstack image list --private --name "${IMAGE_NAME}" -f value -c ID); do
    echo "  deleting image $img_id"
    openstack image delete "$img_id"
done

packer build -var "infra_env=${INFRA_ENV}" -var "network=${NETWORK_ID}" -var "flavor=${FLAVOR}" -var "image_output_name=${IMAGE_NAME}" .
