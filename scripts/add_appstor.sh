#!/usr/bin/env bash
# Provision a new appstor node on OVH Public Cloud.
#
# Usage:
#   ./add_appstor.sh <INFRA_ENV> <CLUSTER_REGION>
#
# Required positional args (or env vars of the same name):
#   INFRA_ENV      — dev | prod
#   CLUSTER_REGION — us-east-1 | us-west-1
#
# Optional env var overrides:
#   IMAGE_NAME      (default: debian13-appstor)
#   FLAVOR          (default: b3-8)
#   PUBLIC_NETWORK  (default: Ext-Net)
#   PRIVATE_NETWORK (default: yag-pn)
#   KEYPAIR         (default: <none> — relies on baked authorized_keys)
#   SERVER_NAME     (default: appstor<NODE_INDEX>-<CLUSTER_REGION>)
#   NODE_INDEX      (default: 0)
#   FQDN_HOST_PREFIX (default: appstor)
#   VOLUME_SIZE     (default: 10, in GBs)
#   BTRFS_DEVICES   (default: /dev/sdb — typical virtio data disk on OVH)
#
# The script creates resources in this order to avoid the volume-not-ready race:
#   1. openstack volume create  (poll until available)
#   2. openstack server create  (without --wait, to get ID before instance boots)
#   3. openstack server add volume  (attaches while instance is still booting)
#   4. Wait for server ACTIVE
#
# NOTE: firstboot.sh must wait for BTRFS_DEVICES to appear on the instance
set -euo pipefail
trap 'rc=$?; echo "ERROR: $BASH_SOURCE:$LINENO: \`${BASH_COMMAND}\` exited with $rc" >&2' ERR

# ---------------------------------------------------------------------------
# Parameters
# ---------------------------------------------------------------------------
INFRA_ENV="${INFRA_ENV:-${1:-}}"
case "$INFRA_ENV" in dev|prod) ;;
    *) echo "INFRA_ENV must be dev|prod, got: '${INFRA_ENV}'" >&2; exit 1;;
esac

CLUSTER_REGION="${CLUSTER_REGION:-${2:-}}"
case "$CLUSTER_REGION" in
    us-east-1|us-west-1) ;;
    *) echo "CLUSTER_REGION must be 'us-east-1' or 'us-west-1', got: '${CLUSTER_REGION}'" >&2; exit 1;;
esac

NODE_INDEX="${NODE_INDEX:-0}"
FQDN_HOST_PREFIX="${FQDN_HOST_PREFIX:-appstor}"

IMAGE_NAME="${IMAGE_NAME:-debian13-appstor}"
FLAVOR="${FLAVOR:-b3-8}"
PUBLIC_NETWORK="${PUBLIC_NETWORK:-Ext-Net}"
PRIVATE_NETWORK="${PRIVATE_NETWORK:-yag-pn}"
SERVER_NAME="${SERVER_NAME:-${FQDN_HOST_PREFIX}${NODE_INDEX}-${CLUSTER_REGION}}"

VOLUME_SIZE="${VOLUME_SIZE:-10}"
BTRFS_DEVICES="${BTRFS_DEVICES:-/dev/sdb}"

# ---------------------------------------------------------------------------
# Source openrc and set region
# ---------------------------------------------------------------------------
OPENRC="${OPENRC:-/workspaces/infra/tofu/envs/${INFRA_ENV}/secrets/openrc}"
if [[ ! -f "$OPENRC" ]]; then
    echo "openrc not found: $OPENRC" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$OPENRC"

case "$CLUSTER_REGION" in
    us-east-1) export OS_REGION_NAME="US-EAST-VA-1" ;;
    us-west-1) export OS_REGION_NAME="US-WEST-OR-1" ;;
esac

# ---------------------------------------------------------------------------
# Derived values
# ---------------------------------------------------------------------------

# Private IP: appstor uses the .200+ octet range within the region subnet.
#   us-east-1 → 192.168.12.200, 192.168.12.201, …
#   us-west-1 → 192.168.13.200, 192.168.13.201, …
case "$CLUSTER_REGION" in
    us-east-1) APPSTOR_NODE_PRIVATE_IP="192.168.12.$((200 + NODE_INDEX))" ;;
    us-west-1) APPSTOR_NODE_PRIVATE_IP="192.168.13.$((200 + NODE_INDEX))" ;;
esac

VOLUME_NAME="${SERVER_NAME}-vol"

# ---------------------------------------------------------------------------
# Pre-flight: verify the image exists in the target region
# ---------------------------------------------------------------------------
IMAGE_ID="$(openstack image list --private --name "$IMAGE_NAME" -f value -c ID 2>/dev/null | head -1)"
if [[ -z "$IMAGE_ID" ]]; then
    echo "ERROR: image '$IMAGE_NAME' not found in region $OS_REGION_NAME." >&2
    echo "       Run: cd /workspaces/infra/packer/images/appstor && ./build.sh ${INFRA_ENV} ${CLUSTER_REGION}" >&2
    exit 1
fi
echo "image '$IMAGE_NAME' found: $IMAGE_ID"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== provisioning appstor node ==="
echo "  env:             $INFRA_ENV"
echo "  region:          $CLUSTER_REGION  (OS_REGION_NAME=$OS_REGION_NAME)"
echo "  server name:     $SERVER_NAME"
echo "  image:           $IMAGE_NAME"
echo "  flavor:          $FLAVOR"
echo "  public network:  $PUBLIC_NETWORK"
echo "  private network: $PRIVATE_NETWORK (fixed ip: $APPSTOR_NODE_PRIVATE_IP)"
echo "  node index:      $NODE_INDEX"
echo "  fqdn prefix:     $FQDN_HOST_PREFIX"
echo "  volume:          $VOLUME_NAME  size=${VOLUME_SIZE} GB"
echo "  btrfs devices:   $BTRFS_DEVICES"
echo

# ---------------------------------------------------------------------------
# Step 1: Create block storage volume (wait until available)
# ---------------------------------------------------------------------------
echo "=== [1/4] creating volume $VOLUME_NAME (${VOLUME_SIZE} GB) ==="
# Look up by name first; create only if it doesn't exist yet.
VOLUME_ID="$(openstack volume list --name "$VOLUME_NAME" -f value -c ID 2>/dev/null | head -1)"
if [[ -z "$VOLUME_ID" ]]; then
    openstack volume create \
        --size "$VOLUME_SIZE" \
        --type "high-speed-gen2" \
        "$VOLUME_NAME"
    VOLUME_ID="$(openstack volume list --name "$VOLUME_NAME" -f value -c ID | head -1)"
else
    echo "volume $VOLUME_NAME already exists, reusing id: $VOLUME_ID"
fi
echo "volume id: $VOLUME_ID"
# poll until available (volume create has no --wait flag)
for _i in $(seq 1 30); do
    _status="$(openstack volume show "$VOLUME_ID" -f value -c status)"
    [[ "$_status" == "available" ]] && break
    echo "  volume status: ${_status} (${_i}/30)..."
    sleep 5
done
if [[ "$(openstack volume show "$VOLUME_ID" -f value -c status)" != "available" ]]; then
    echo "ERROR: volume $VOLUME_NAME did not reach 'available' after 150 s" >&2
    exit 1
fi
echo

# ---------------------------------------------------------------------------
# Step 2: Build user-data for cloud-init / firstboot
# ---------------------------------------------------------------------------
USERDATA_FILE="$(mktemp /tmp/appstor-userdata.XXXXXX.yml)"
trap 'rm -f "$USERDATA_FILE"' EXIT

cat > "$USERDATA_FILE" <<EOF
#cloud-config
write_files:
  - path: /etc/appstor/boot.env
    permissions: '0644'
    owner: root:root
    content: |
      APPSTOR_NODE_PRIVATE_IP=${APPSTOR_NODE_PRIVATE_IP}
      BTRFS_DEVICES=${BTRFS_DEVICES}
      CLUSTER_REGION=${CLUSTER_REGION}
      NODE_INDEX=${NODE_INDEX}
      FQDN_HOST_PREFIX=${FQDN_HOST_PREFIX}

runcmd:
  - |
    priv=\$(ip -4 -o addr show | awk -v ip="${APPSTOR_NODE_PRIVATE_IP}" '\$4~("^"ip"/"){print \$2;exit}')
    gw=\$(ip route show dev "\$priv" | awk '/^default/{print \$3;exit}')
    ip route del default dev "\$priv" 2>/dev/null; ip route add default via "\$gw" dev "\$priv" metric 200
EOF

# ---------------------------------------------------------------------------
# Step 3: Create instance and wait for ACTIVE, then attach volume.
#         OVH rejects volume attachments while the server is in 'building'
#         state.  firstboot.sh has a device-wait loop that tolerates the
#         short gap between ACTIVE and the volume becoming visible.
# ---------------------------------------------------------------------------
echo "=== [2/4] creating instance $SERVER_NAME ==="

PRIVATE_NETWORK_ID="$(openstack network show "$PRIVATE_NETWORK" -f value -c id)"

create_args=(
    --image "$IMAGE_NAME"
    --flavor "$FLAVOR"
    --network "$PUBLIC_NETWORK"
    --nic "net-id=${PRIVATE_NETWORK_ID},v4-fixed-ip=${APPSTOR_NODE_PRIVATE_IP}"
    --user-data "$USERDATA_FILE"
)
if [[ -n "${KEYPAIR:-}" ]]; then
    create_args+=(--key-name "$KEYPAIR")
fi

openstack server create "${create_args[@]}" "$SERVER_NAME"
SERVER_ID="$(openstack server show "$SERVER_NAME" -f value -c id)"
echo "server id: $SERVER_ID"
echo

# ---------------------------------------------------------------------------
# Step 4: Wait for instance to reach ACTIVE before attaching the volume.
#         OVH returns 409 if you attach while vm_state=building.
# ---------------------------------------------------------------------------
echo "=== [3/4] waiting for $SERVER_NAME to become ACTIVE ==="
for _i in $(seq 1 60); do
    _state="$(openstack server show "$SERVER_ID" -f value -c status)"
    [[ "$_state" == "ACTIVE" ]] && break
    if [[ "$_state" == "ERROR" ]]; then
        echo "ERROR: server $SERVER_NAME entered ERROR state" >&2; exit 1
    fi
    echo "  server status: ${_state} (${_i}/60)..."
    sleep 5
done
if [[ "$(openstack server show "$SERVER_ID" -f value -c status)" != "ACTIVE" ]]; then
    echo "ERROR: server $SERVER_NAME did not reach ACTIVE after 300 s" >&2; exit 1
fi

# ---------------------------------------------------------------------------
# Step 5: Attach volume.
#         firstboot.sh polls for the block device, so there is no race.
# ---------------------------------------------------------------------------
echo "=== [4/4] attaching volume $VOLUME_NAME to $SERVER_NAME ==="
openstack server add volume "$SERVER_ID" "$VOLUME_ID"
echo "volume attached."

echo
echo "=== server details ==="
openstack server show "$SERVER_NAME" -f value -c id -c status -c addresses

ADDRESSES_RAW="$(openstack server show "$SERVER_NAME" -f value -c addresses)"
extract_ipv4() {
    local net="$1"
    python3 -c "
import ast, re, sys
data = ast.literal_eval(sys.argv[1])
for ip in data.get(sys.argv[2], []):
    if re.match(r'^\d+\.\d+\.\d+\.\d+$', ip):
        print(ip); break
" "$ADDRESSES_RAW" "$net" 2>/dev/null || true
}
PUBLIC_IP="$(extract_ipv4 "$PUBLIC_NETWORK")"
PRIVATE_IP="$(extract_ipv4 "$PRIVATE_NETWORK")"

echo
echo "Public IP:  ${PUBLIC_IP:-<unknown>}"
echo "Private IP: ${PRIVATE_IP:-<unknown>}"
echo
cat <<EOF
Next steps:
  # tail console log until firstboot finishes
  source /workspaces/infra/tofu/envs/${INFRA_ENV}/secrets/openrc
  export OS_REGION_NAME="${OS_REGION_NAME}"
  openstack console log show $SERVER_NAME | tail -80

  # ssh in (uses key baked into the image)
  ssh -i /workspaces/infra/tofu/modules/bastion/files/secrets/${INFRA_ENV}/id_ed25519 \\
      -o StrictHostKeyChecking=no debian@${PUBLIC_IP:-<ip>}

  # verify firstboot ran
  systemctl status appstor-firstboot.service
  cat /etc/appstor/boot.env
  ls -l /var/lib/appstor/.bootstrapped
  docker ps

  # tear down if needed
  DELETE_VOLUME=true ./rm_node.sh ${INFRA_ENV} ${CLUSTER_REGION} $SERVER_ID
EOF
