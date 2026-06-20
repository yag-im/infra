#!/usr/bin/env bash
# Delete an OVH compute instance (and optionally its attached volume).
#
# Usage:
#   ./rm_node.sh <INFRA_ENV> <CLUSTER_REGION> <SERVER_NAME_OR_ID>
#
# Required positional args (or env vars of the same name):
#   INFRA_ENV            — dev | prod
#   CLUSTER_REGION       — us-east-1 | us-west-1
#   SERVER_NAME          — server name or UUID to delete
#
# Optional env var overrides:
#   DELETE_VOLUME        — set to 'true' to also delete the attached volume
#                          (default: false — volume is kept for safety)
#   OPENRC               — path to openrc file
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

SERVER_NAME="${SERVER_NAME:-${3:-}}"
if [[ -z "$SERVER_NAME" ]]; then
    echo "SERVER_NAME (3rd positional arg) is required" >&2
    exit 1
fi

DELETE_VOLUME="${DELETE_VOLUME:-false}"

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
# Resolve server ID
# ---------------------------------------------------------------------------
SERVER_ID="$(openstack server show "$SERVER_NAME" -f value -c id 2>/dev/null || true)"
if [[ -z "$SERVER_ID" ]]; then
    echo "server '$SERVER_NAME' not found in region $OS_REGION_NAME" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Collect attached volume IDs
# ---------------------------------------------------------------------------
VOLUME_IDS=()
while IFS= read -r vid; do
    [[ -n "$vid" ]] && VOLUME_IDS+=("$vid")
done < <(openstack server show "$SERVER_ID" -f json \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for v in data.get('volumes_attached', []):
    print(v.get('id', ''))
" 2>/dev/null || true)

# ---------------------------------------------------------------------------
# Summary + confirmation
# ---------------------------------------------------------------------------
echo "=== deleting server ==="
echo "  env:     $INFRA_ENV"
echo "  region:  $CLUSTER_REGION  (OS_REGION_NAME=$OS_REGION_NAME)"
echo "  server:  $SERVER_NAME  ($SERVER_ID)"
if [[ "${#VOLUME_IDS[@]}" -gt 0 ]]; then
    if [[ "$DELETE_VOLUME" == "true" ]]; then
        echo "  volumes: ${VOLUME_IDS[*]}  (will be deleted)"
    else
        echo "  volumes: ${VOLUME_IDS[*]}  (kept — use DELETE_VOLUME=true to delete)"
    fi
else
    echo "  volumes: no volumes attached"
fi
echo

read -r -p "Confirm deletion? [y/N] " _confirm
case "$_confirm" in y|Y) ;; *)
    echo "aborted." >&2; exit 1;;
esac

# ---------------------------------------------------------------------------
# Delete server
# ---------------------------------------------------------------------------
echo "deleting server $SERVER_NAME ..."
openstack server delete "$SERVER_NAME"
# poll until gone
for _i in $(seq 1 30); do
    _found="$(openstack server list --name "$SERVER_NAME" -f value -c ID 2>/dev/null | head -1)"
    [[ -z "$_found" ]] && break
    echo "  waiting for deletion (${_i}/30)..."
    sleep 5
done
echo "server deleted."

# ---------------------------------------------------------------------------
# Delete volumes (if requested)
# ---------------------------------------------------------------------------
if [[ "$DELETE_VOLUME" == "true" ]]; then
    for _vid in "${VOLUME_IDS[@]}"; do
        # Wait for Cinder to detach (volume may still be 'in-use' briefly after server is gone)
        echo "waiting for volume $_vid to become available..."
        for _i in $(seq 1 30); do
            _vstatus="$(openstack volume show "$_vid" -f value -c status 2>/dev/null || true)"
            [[ "$_vstatus" == "available" ]] && break
            echo "  volume status: ${_vstatus} (${_i}/30)..."
            sleep 5
        done
        if [[ "$(openstack volume show "$_vid" -f value -c status 2>/dev/null || true)" != "available" ]]; then
            echo "ERROR: volume $_vid did not reach 'available' after 150 s" >&2
            exit 1
        fi
        echo "deleting volume $_vid ..."
        openstack volume delete "$_vid"
        echo "volume $_vid deleted."
    done
fi

echo
echo "done."
