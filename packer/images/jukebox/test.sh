#!/usr/bin/env bash
# Launch a test instance from the baked image and wait for cloud-init/firstboot.
#
# Usage:
#   ./test.sh [INFRA_ENV [CLUSTER_REGION [GPU_VENDOR]]]
#
# Env overrides (take precedence over positional args):
#   INFRA_ENV      (default: dev)
#   CLUSTER_REGION (default: us-east-1)
#   GPU_VENDOR     (default: nvidia) — set to 'nvidia' for NVIDIA GPU, leave empty for CPU-only
#   IMAGE_NAME (default: debian13-jukebox-gpu-nvidia when GPU_VENDOR=nvidia, else debian13-jukebox-cpu)
#   FLAVOR (default: l4-90 when GPU_VENDOR=nvidia, else b2-7)
#   PUBLIC_NETWORK (default: Ext-Net) — public network
#   PRIVATE_NETWORK (default: yag-pn) — private network
#   KEYPAIR (default: <none> — relies on baked authorized_keys)
#   SERVER_NAME (default: test-jukebox-<random>)
#   APPSTOR_INTERNAL_IPS, NODE_INDEX, FQDN_HOST_PREFIX
#       (have sane dev defaults; private IP is derived from region+node index)
set -euo pipefail
trap 'rc=$?; echo "ERROR: $BASH_SOURCE:$LINENO: \`${BASH_COMMAND}\` exited with $rc" >&2' ERR

INFRA_ENV="${INFRA_ENV:-${1:-dev}}"
case "$INFRA_ENV" in dev|local|prod) ;; *)
    echo "INFRA_ENV must be dev|local|prod, got: $INFRA_ENV" >&2; exit 1;;
esac

CLUSTER_REGION="${CLUSTER_REGION:-${2:-us-east-1}}"
case "$CLUSTER_REGION" in
    us-east-1|us-west-1) ;;
    *)
        echo "CLUSTER_REGION must be 'us-east-1' or 'us-west-1', got: $CLUSTER_REGION" >&2; exit 1;;
esac

GPU_VENDOR="${GPU_VENDOR:-${3:-nvidia}}"
case "$GPU_VENDOR" in
    nvidia|"") ;;
    *)
        echo "GPU_VENDOR must be 'nvidia' or empty, got: $GPU_VENDOR" >&2; exit 1;;
esac

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

GPU_VENDOR="${GPU_VENDOR:-${3:-nvidia}}"
if [[ "$GPU_VENDOR" == "nvidia" ]]; then
    IMAGE_NAME="${IMAGE_NAME:-debian13-jukebox-gpu-nvidia}"
    FLAVOR="${FLAVOR:-l4-90}"
else # cpu. TODO: gpu-intel
    IMAGE_NAME="${IMAGE_NAME:-debian13-jukebox-cpu}"
    FLAVOR="${FLAVOR:-b2-7}"
fi
PUBLIC_NETWORK="${PUBLIC_NETWORK:-Ext-Net}"
PRIVATE_NETWORK="${PRIVATE_NETWORK:-yag-pn}"
SERVER_NAME="${SERVER_NAME:-test-jukebox-$(date +%s)}"

JUKEBOX_CLUSTER_NODE_PRIVATE_IP=""
APPSTOR_INTERNAL_IPS="${APPSTOR_INTERNAL_IPS:-192.168.12.200}"
NODE_INDEX="${NODE_INDEX:-0}"
FQDN_HOST_PREFIX="${FQDN_HOST_PREFIX:-jukebox}"

# Derive private IP from region + node index:
#   us-east-1 -> 192.168.12.(100+NODE_INDEX)
#   us-west-1 -> 192.168.13.(100+NODE_INDEX)
case "$CLUSTER_REGION" in
    us-east-1) JUKEBOX_CLUSTER_NODE_PRIVATE_IP="192.168.12.$((100 + NODE_INDEX))" ;;
    us-west-1) JUKEBOX_CLUSTER_NODE_PRIVATE_IP="192.168.13.$((100 + NODE_INDEX))" ;;
    *)
        echo "no private IP mapping for CLUSTER_REGION=$CLUSTER_REGION" >&2
        exit 1
        ;;
esac

USERDATA_FILE="$(mktemp /tmp/jukebox-userdata.XXXXXX.yml)"
trap 'rm -f "$USERDATA_FILE"' EXIT

cat > "$USERDATA_FILE" <<EOF
#cloud-config
write_files:
  - path: /etc/jukebox/node.env
    permissions: '0644'
    owner: root:root
    content: |
      JUKEBOX_CLUSTER_NODE_PRIVATE_IP=${JUKEBOX_CLUSTER_NODE_PRIVATE_IP}
      APPSTOR_INTERNAL_IPS="${APPSTOR_INTERNAL_IPS}"
      NODE_INDEX=${NODE_INDEX}
      FQDN_HOST_PREFIX=${FQDN_HOST_PREFIX}
      CLUSTER_REGION=${CLUSTER_REGION}
EOF

echo "=== launching $SERVER_NAME ==="
echo "  image:           $IMAGE_NAME"
echo "  flavor:          $FLAVOR"
echo "  public network:  $PUBLIC_NETWORK"
echo "  private network: $PRIVATE_NETWORK (fixed ip: $JUKEBOX_CLUSTER_NODE_PRIVATE_IP)"
echo "  user-data:       $USERDATA_FILE"
echo "  region:          $CLUSTER_REGION"
echo

# Resolve the private network's neutron ID so we can pin a fixed IP via --nic.
# `openstack server create --network <name>` does not accept v4-fixed-ip; only
# the --nic net-id=<id>,v4-fixed-ip=<ip> form does.
PRIVATE_NETWORK_ID="$(openstack network show "$PRIVATE_NETWORK" -f value -c id)"

create_args=(
    --image "$IMAGE_NAME"
    --flavor "$FLAVOR"
    --nic "net-id=${PRIVATE_NETWORK_ID},v4-fixed-ip=${JUKEBOX_CLUSTER_NODE_PRIVATE_IP}"
    --network "$PUBLIC_NETWORK"
    --user-data "$USERDATA_FILE"
    --wait
)
if [[ -n "${KEYPAIR:-}" ]]; then
    create_args+=(--key-name "$KEYPAIR")
fi

openstack server create "${create_args[@]}" "$SERVER_NAME"

echo
echo "=== server details ==="
openstack server show "$SERVER_NAME" -f value -c id -c status -c addresses

# addresses comes back as a Python dict literal, e.g.:
#   {'yag-pn': ['192.168.1.31'], 'Ext-Net': ['2604:...', '147.135.78.188']}
# Parse it with python and pick the first IPv4 per network.
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

  # ssh in (uses key baked into the image via genesis/files/ssh/${INFRA_ENV}/id_ed25519.pub)
  ssh -i /workspaces/infra/tofu/modules/bastion/files/secrets/${INFRA_ENV}/id_ed25519 \\
      -o StrictHostKeyChecking=no debian@${PUBLIC_IP:-<ip>}

  # verify firstboot ran
  systemctl status jukebox-firstboot.service
  cat /etc/jukebox/node.env
  ls -l /var/lib/jukebox/.bootstrapped
  docker ps

  # verify GPU is visible if testing GPU image:
  nvidia-smi

  # tear down when done
  openstack server delete $SERVER_NAME
EOF
