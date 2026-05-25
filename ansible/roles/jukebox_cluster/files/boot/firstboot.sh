#!/usr/bin/env bash
# First-boot specialization for jukebox cloud nodes.
# Reads /etc/jukebox/node.env (delivered via cloud-init user-data) and:
#   1. validates required vars and that the private IP is actually on the host
#   2. renders /etc/systemd/system/docker.service.d/override.conf
#   3. restarts docker so dockerd binds to the private IP
#   4. creates the appstor NFS docker volume
#   5. sets the FQDN hostname
#   6. writes a sentinel so the unit never runs again
set -euo pipefail

SENTINEL=/var/lib/jukebox/.bootstrapped
BOOT_DIR=/opt/jukebox-boot
BAKED_ENV=/etc/jukebox/baked.env

if [[ -f "$BAKED_ENV" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$BAKED_ENV"; set +a
fi

require() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        echo "firstboot: required variable '$name' is not set in /etc/jukebox/node.env" >&2
        exit 1
    fi
}

require JUKEBOX_CLUSTER_NODE_PRIVATE_IP
require APPSTOR_INTERNAL_IPS
require NODE_INDEX
require FQDN_HOST_PREFIX
require CLUSTER_REGION

# Cross-check that the private IP from user-data matches an interface on this host.
if ! ip -4 addr show | grep -qE "inet ${JUKEBOX_CLUSTER_NODE_PRIVATE_IP}/"; then
    echo "firstboot: JUKEBOX_CLUSTER_NODE_PRIVATE_IP=${JUKEBOX_CLUSTER_NODE_PRIVATE_IP} is not assigned to any interface" >&2
    ip -4 addr show >&2
    exit 1
fi

export JUKEBOX_CLUSTER_NODE_PRIVATE_IP

install -d /etc/systemd/system/docker.service.d
envsubst '${JUKEBOX_CLUSTER_NODE_PRIVATE_IP}' \
    < "${BOOT_DIR}/templates/override.conf.tmpl" \
    > /etc/systemd/system/docker.service.d/override.conf

systemctl daemon-reload
systemctl restart docker

# Wait for docker daemon to come back up before creating the NFS volume.
for _ in $(seq 1 30); do
    if docker info >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
docker info >/dev/null

# TEMP: appstor NFS mount disabled for test instances (no appstor reachable).
# read -ra _appstor_ips <<< "$APPSTOR_INTERNAL_IPS"
# for i in "${!_appstor_ips[@]}"; do
#     vol="appstor-vol${i}"
#     ip="${_appstor_ips[$i]}"
#     if ! docker volume inspect "$vol" >/dev/null 2>&1; then
#         docker volume create \
#             --driver local \
#             --opt type=nfs \
#             --opt device=":/clones${i}" \
#             --opt o="addr=${ip},rw,nfsvers=4,minorversion=2,proto=tcp,fsc,nocto" \
#             "$vol"
#     fi
# done

hostnamectl set-hostname "${FQDN_HOST_PREFIX}${NODE_INDEX}.${CLUSTER_REGION}.yag.im"

# otel-collector: container was created (state=present) during bake with the
# desired spec and restart_policy=always. Render the config placeholder and
# start it once; docker will restart it on every subsequent boot.
if [[ -n "${OTEL_CONFIG_PATH:-}" && -f "${OTEL_CONFIG_PATH}" ]]; then
    export CLUSTER_REGION
    tmp="$(mktemp)"
    envsubst '${CLUSTER_REGION}' < "${OTEL_CONFIG_PATH}" > "${tmp}"
    mv "${tmp}" "${OTEL_CONFIG_PATH}"
    docker start otel-collector
fi

install -d "$(dirname "$SENTINEL")"
touch "$SENTINEL"
