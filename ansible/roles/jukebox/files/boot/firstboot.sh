#!/usr/bin/env bash
# First-boot specialization for jukebox cloud nodes.
# Reads /etc/jukebox/boot.env (delivered via cloud-init user-data) and:
#   1. validates required vars and that the private IP is actually on the host
#   2. renders /etc/systemd/system/docker.service.d/override.conf
#   3. restarts docker so dockerd binds to the private IP
#   4. creates the appstor NFS docker volume
#   5. sets the FQDN hostname
#   6. writes a sentinel so the unit never runs again
set -euo pipefail

SENTINEL=/var/lib/jukebox/.bootstrapped
BOOT_DIR=/opt/yag/jukebox/boot
IMAGE_ENV=/etc/jukebox/image.env

if [[ -f "$IMAGE_ENV" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$IMAGE_ENV"; set +a
fi

require() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        echo "firstboot: required variable '$name' is not set in /etc/jukebox/boot.env" >&2
        exit 1
    fi
}

require JUKEBOX_NODE_PRIVATE_IP
require APPSTOR_NUM
require NODE_INDEX
require FQDN_HOST_PREFIX
require CLUSTER_REGION

# Cross-check that the private IP from user-data matches an interface on this host.
if ! ip -4 addr show | grep -qE "inet ${JUKEBOX_NODE_PRIVATE_IP}/"; then
    echo "firstboot: JUKEBOX_NODE_PRIVATE_IP=${JUKEBOX_NODE_PRIVATE_IP} is not assigned to any interface" >&2
    ip -4 addr show >&2
    exit 1
fi

export JUKEBOX_NODE_PRIVATE_IP

install -d /etc/systemd/system/docker.service.d
envsubst '${JUKEBOX_NODE_PRIVATE_IP}' \
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

# Inject regional /etc/hosts entries so appstor hostnames resolve.
HOSTS_SRC="${BOOT_DIR}/templates/hosts.${CLUSTER_REGION}"
if [[ -f "$HOSTS_SRC" ]]; then
    block="$(cat "$HOSTS_SRC")"
    # idempotent: only add once (sentinel guarantees this, but be safe)
    if ! grep -qF 'ANSIBLE MANAGED BLOCK - regional hosts' /etc/hosts; then
        printf '\n# BEGIN ANSIBLE MANAGED BLOCK - regional hosts\n%s\n# END ANSIBLE MANAGED BLOCK - regional hosts\n' "$block" >> /etc/hosts
    fi
else
    echo "firstboot: no hosts file found for CLUSTER_REGION=${CLUSTER_REGION}" >&2
fi

# appstors are resolvable by their hostnames (regional /etc/hosts block injected below after CLUSTER_REGION is known)
for i in $(seq 0 $((APPSTOR_NUM - 1))); do
    vol="appstor${i}-vol"
    appstor_host="appstor${i}"
    if ! docker volume inspect "$vol" >/dev/null 2>&1; then
        docker volume create \
            --driver local \
            --opt type=nfs \
            --opt device=":/clones" \
            --opt o="addr=${appstor_host},rw,nfsvers=4,minorversion=2,proto=tcp,fsc,nocto" \
            "$vol"
    fi
done

# Set the FQDN hostname before starting any containers so that gethostname()
# inside containers using --network host returns the correct name from the
# moment they start (Docker shares the host UTS namespace in host-network mode).
hostnamectl set-hostname "${FQDN_HOST_PREFIX}${NODE_INDEX}-${CLUSTER_REGION}"

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
