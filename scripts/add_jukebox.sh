#!/usr/bin/env bash
# Provision a new jukebox node on OVH Public Cloud.
#
# Usage:
#   ./add_jukebox.sh <INFRA_ENV> <CLUSTER_REGION> [GPU_VENDOR]
#
# Required positional args (or env vars of the same name):
#   INFRA_ENV      — dev | prod
#   CLUSTER_REGION — us-east-1 | us-west-1
#
# Optional positional arg / env var:
#   GPU_VENDOR     — nvidia (default) | "" (CPU-only)
#
# Optional env var overrides:
#   IMAGE_NAME      (default: debian13-jukebox-gpu-nvidia when GPU_VENDOR=nvidia, else debian13-jukebox-cpu)
#   FLAVOR          (default: l4-90 when GPU_VENDOR=nvidia, else b2-7)
#   PUBLIC_NETWORK  (default: Ext-Net)
#   PRIVATE_NETWORK (default: yag-pn)
#   KEYPAIR         (default: <none> — relies on baked authorized_keys)
#   SERVER_NAME     (default: <FQDN_HOST_PREFIX><NODE_INDEX>-<CLUSTER_REGION>)
#   NODE_INDEX      (default: 0)
#   FQDN_HOST_PREFIX (default: jukebox)
#   APPSTOR_NUM     (default: 1)
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

GPU_VENDOR="${GPU_VENDOR:-${3:-nvidia}}"
case "$GPU_VENDOR" in
    nvidia|"") ;;
    *) echo "GPU_VENDOR must be 'nvidia' or empty (CPU-only), got: '${GPU_VENDOR}'" >&2; exit 1;;
esac

NODE_INDEX="${NODE_INDEX:-0}"
FQDN_HOST_PREFIX="${FQDN_HOST_PREFIX:-jukebox}"
APPSTOR_NUM="${APPSTOR_NUM:-1}"

if [[ "$GPU_VENDOR" == "nvidia" ]]; then
    IMAGE_NAME="${IMAGE_NAME:-debian13-jukebox-gpu-nvidia}"
    FLAVOR="${FLAVOR:-l4-90}"
else
    IMAGE_NAME="${IMAGE_NAME:-debian13-jukebox-cpu}"
    FLAVOR="${FLAVOR:-b2-7}"
fi

PUBLIC_NETWORK="${PUBLIC_NETWORK:-Ext-Net}"
PRIVATE_NETWORK="${PRIVATE_NETWORK:-yag-pn}"
SERVER_NAME="${SERVER_NAME:-${FQDN_HOST_PREFIX}${NODE_INDEX}-${CLUSTER_REGION}}"

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

# Private IP: jukebox uses the .2+ octet range within the region subnet.
#   us-east-1 → 192.168.12.2, 192.168.12.3, …
#   us-west-1 → 192.168.13.2, 192.168.13.3, …
case "$CLUSTER_REGION" in
    us-east-1) JUKEBOX_NODE_PRIVATE_IP="192.168.12.$((2 + NODE_INDEX))" ;;
    us-west-1) JUKEBOX_NODE_PRIVATE_IP="192.168.13.$((2 + NODE_INDEX))" ;;
esac

# ---------------------------------------------------------------------------
# Pre-flight: verify the image exists in the target region
# ---------------------------------------------------------------------------
IMAGE_ID="$(openstack image list --private --name "$IMAGE_NAME" -f value -c ID 2>/dev/null | head -1)"
if [[ -z "$IMAGE_ID" ]]; then
    echo "ERROR: image '$IMAGE_NAME' not found in region $OS_REGION_NAME." >&2
    echo "       Run: cd /workspaces/infra/packer/images/jukebox && ./build.sh ${INFRA_ENV} ${CLUSTER_REGION}" >&2
    exit 1
fi
echo "image '$IMAGE_NAME' found: $IMAGE_ID"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== provisioning jukebox node ==="
echo "  env:             $INFRA_ENV"
echo "  region:          $CLUSTER_REGION  (OS_REGION_NAME=$OS_REGION_NAME)"
echo "  server name:     $SERVER_NAME"
echo "  image:           $IMAGE_NAME"
echo "  flavor:          $FLAVOR"
echo "  gpu vendor:      ${GPU_VENDOR:-<none, CPU-only>}"
echo "  public network:  $PUBLIC_NETWORK"
echo "  private network: $PRIVATE_NETWORK (fixed ip: $JUKEBOX_NODE_PRIVATE_IP)"
echo "  node index:      $NODE_INDEX"
echo "  fqdn prefix:     $FQDN_HOST_PREFIX"
echo "  appstor num:     $APPSTOR_NUM"
echo

# ---------------------------------------------------------------------------
# Build user-data for cloud-init / firstboot
# ---------------------------------------------------------------------------
USERDATA_FILE="$(mktemp /tmp/jukebox-userdata.XXXXXX.yml)"
trap 'rm -f "$USERDATA_FILE"' EXIT

cat > "$USERDATA_FILE" <<EOF
#cloud-config
write_files:
  - path: /etc/jukebox/boot.env
    permissions: '0644'
    owner: root:root
    content: |
      JUKEBOX_NODE_PRIVATE_IP=${JUKEBOX_NODE_PRIVATE_IP}
      APPSTOR_NUM=${APPSTOR_NUM}
      NODE_INDEX=${NODE_INDEX}
      FQDN_HOST_PREFIX=${FQDN_HOST_PREFIX}
      CLUSTER_REGION=${CLUSTER_REGION}

runcmd:
  - |
    priv=\$(ip -4 -o addr show | awk -v ip="${JUKEBOX_NODE_PRIVATE_IP}" '\$4~("^"ip"/"){print \$2;exit}')
    gw=\$(ip route show dev "\$priv" | awk '/^default/{print \$3;exit}')
    ip route del default dev "\$priv" 2>/dev/null; ip route add default via "\$gw" dev "\$priv" metric 200
EOF

# ---------------------------------------------------------------------------
# Create instance and wait for ACTIVE
# ---------------------------------------------------------------------------
echo "=== [1/1] creating instance $SERVER_NAME ==="

PRIVATE_NETWORK_ID="$(openstack network show "$PRIVATE_NETWORK" -f value -c id)"

create_args=(
    --image "$IMAGE_NAME"
    --flavor "$FLAVOR"
    --network "$PUBLIC_NETWORK"
    --nic "net-id=${PRIVATE_NETWORK_ID},v4-fixed-ip=${JUKEBOX_NODE_PRIVATE_IP}"
    --user-data "$USERDATA_FILE"
    --wait
)
if [[ -n "${KEYPAIR:-}" ]]; then
    create_args+=(--key-name "$KEYPAIR")
fi

openstack server create "${create_args[@]}" "$SERVER_NAME"
SERVER_ID="$(openstack server show "$SERVER_NAME" -f value -c id)"
echo "server id: $SERVER_ID"

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
  systemctl status jukebox-firstboot.service
  cat /etc/jukebox/boot.env
  ls -l /var/lib/jukebox/.bootstrapped
  docker ps

  # verify GPU is visible (GPU image only)
  nvidia-smi

  # tear down if needed
  ./rm_node.sh ${INFRA_ENV} ${CLUSTER_REGION} $SERVER_ID
EOF
