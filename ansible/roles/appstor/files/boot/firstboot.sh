#!/usr/bin/env bash
# First-boot specialization for appstor cloud nodes.
# Reads /etc/appstor/boot.env (delivered via cloud-init user-data) and:
#   1. validates required vars and that the private IP is actually on the host
#   2. initializes btrfs filesystem (mkfs, mount, subdirs)
#   3. configures and starts bees deduplication daemon
#   4. starts NFS server docker container
#   5. substitutes ${CLUSTER_REGION} in otel config and starts otel-collector
#   6. sets the FQDN hostname
#   7. writes a sentinel so the unit never runs again
set -euo pipefail

SENTINEL=/var/lib/appstor/.bootstrapped
BOOT_DIR=/opt/yag/appstor/boot
IMAGE_ENV=/etc/appstor/image.env

if [[ -f "$IMAGE_ENV" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$IMAGE_ENV"; set +a
fi

require() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        echo "firstboot: required variable '$name' is not set in /etc/appstor/boot.env" >&2
        exit 1
    fi
}

require APPSTOR_NODE_PRIVATE_IP
require BTRFS_DEVICES
require CLUSTER_REGION
require NODE_INDEX
require FQDN_HOST_PREFIX

# Cross-check that the private IP from user-data matches an interface on this host.
if ! ip -4 addr show | grep -qE "inet ${APPSTOR_NODE_PRIVATE_IP}/"; then
    echo "firstboot: APPSTOR_NODE_PRIVATE_IP=${APPSTOR_NODE_PRIVATE_IP} is not assigned to any interface" >&2
    ip -4 addr show >&2
    exit 1
fi

# Static defaults (can be overridden via image.env)
APP_DATA_PATH="${APP_DATA_PATH:-/opt/yag/data/appstor}"
APP_PATH="${APP_PATH:-/opt/yag/appstor}"
BTRFS_PROFILE="${BTRFS_PROFILE:-single}"
ANSIBLE_USER="${ANSIBLE_USER:-debian}"

# --- 1. wait for block device (volume attach may race with boot) ---
read -ra _btrfs_devs <<< "$BTRFS_DEVICES"
_wait_dev="${_btrfs_devs[0]}"
for _i in $(seq 1 60); do
    [[ -b "$_wait_dev" ]] && break
    echo "firstboot: waiting for ${_wait_dev} (${_i}/60)..." >&2
    sleep 5
done
if [[ ! -b "$_wait_dev" ]]; then
    echo "firstboot: ${_wait_dev} not available after 5 minutes" >&2
    exit 1
fi

# --- 3. btrfs filesystem ---
if ! mountpoint -q "$APP_DATA_PATH"; then
    mkdir -p "$APP_DATA_PATH"
    read -ra devices <<< "$BTRFS_DEVICES"
    mkfs.btrfs -d "$BTRFS_PROFILE" -m "$BTRFS_PROFILE" "${devices[@]}" || true  # no-op if already formatted
    mount -o defaults,compress=zstd "${devices[0]}" "$APP_DATA_PATH"

    BTRFS_UUID_FSTAB="$(blkid -s UUID -o value "${devices[0]}")"
    if ! grep -qF "$BTRFS_UUID_FSTAB" /etc/fstab; then
        echo "UUID=${BTRFS_UUID_FSTAB} ${APP_DATA_PATH} btrfs defaults,compress=zstd 0 0" >> /etc/fstab
    fi

    mkdir -p \
        "${APP_DATA_PATH}/apps" \
        "${APP_DATA_PATH}/clones" \
        "${APP_DATA_PATH}/tmp"
    chown -R 1000:1000 "${APP_DATA_PATH}"
fi

# --- 4. bees deduplication ---
read -ra devices <<< "$BTRFS_DEVICES"
BTRFS_UUID="$(blkid -s UUID -o value "${devices[0]}")"
mkdir -p /etc/bees
cat > /etc/bees/beesd.conf <<EOF
UUID=${BTRFS_UUID}
OPTIONS="--strip-paths --verbose 6"
DB_SIZE=$((1024*1024*1024)) # 1G in bytes
EOF

systemctl daemon-reload
systemctl enable --now "beesd@${BTRFS_UUID}"

# --- 5. NFS server container ---
if ! docker ps -a --format '{{.Names}}' | grep -q '^appstor$'; then
    docker run -d \
        --name appstor \
        --privileged \
        --restart always \
        --stop-timeout 10 \
        -v "${APP_DATA_PATH}:/mnt" \
        -v "${APP_PATH}/exports:/etc/exports:ro" \
        -v "/lib/modules:/lib/modules:ro" \
        -e NFS_VERSION=4.2 \
        -e NFS_DISABLE_VERSION_3=1 \
        -e NFS_LOG_LEVEL=DEBUG \
        -p "${APPSTOR_NODE_PRIVATE_IP}:2049:2049" \
        --log-driver json-file \
        --log-opt max-size=100m \
        --log-opt max-file=10 \
        erichough/nfs-server@sha256:784ef30907aa318b8324c4c49bd258b11a740ab0eea9f09b5ccf9df378fa77ca
else
    docker start appstor
fi

# --- 5. hostname ---
hostnamectl set-hostname "${FQDN_HOST_PREFIX}${NODE_INDEX}-${CLUSTER_REGION}"

# --- 6. otel-collector ---
if [[ -n "${OTEL_CONFIG_PATH:-}" && -f "${OTEL_CONFIG_PATH}" ]]; then
    export CLUSTER_REGION
    tmp="$(mktemp)"
    envsubst '${CLUSTER_REGION}' < "${OTEL_CONFIG_PATH}" > "${tmp}"
    mv "${tmp}" "${OTEL_CONFIG_PATH}"
    docker run -d \
        --name otel-collector \
        --user 0 \
        --privileged \
        --network host \
        --ipc host \
        --pid host \
        --stop-timeout 10 \
        --hostname "${FQDN_HOST_PREFIX}${NODE_INDEX}-${CLUSTER_REGION}" \
        --add-host "${OTELCOL_GW_HOST}:${OTELCOL_GW_IP}" \
        --volume "${OTEL_CONFIG_PATH}:/otel-config.yml:ro" \
        --volume "/var/run/docker.sock:/var/run/docker.sock:ro" \
        --volume "/etc/passwd:/etc/passwd:ro" \
        --volume "/proc:/hostfs/proc:ro" \
        --log-driver json-file \
        --log-opt max-size=50m \
        --log-opt max-file=10 \
        --restart always \
        "${OTELCOL_IMAGE}" \
        --config otel-config.yml
fi

install -d "$(dirname "$SENTINEL")"
touch "$SENTINEL"
