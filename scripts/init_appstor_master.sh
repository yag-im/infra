#!/usr/bin/env bash
# Initialize the appstor master node with lsyncd replication.
#
# This is a one-time manual step after the master node has booted and
# passed firstboot. It configures lsyncd to replicate to peer nodes.
#
# Usage:
#   ./init_appstor_master.sh <INFRA_ENV>
#
# Required positional args (or env vars of the same name):
#   INFRA_ENV — dev | prod
#
# Optional env var overrides:
#   APPSTOR_REPLICAS       (default: appstor0-us-west-1)
#   ANSIBLE_USER           (default: debian)
#   CLUSTER_REGION         (default: us-east-1, where master always lives)
#   VAULT_PASSWORD_FILE    (default: ansible/.vault_pwd)
#   SSH_KEY_FILE           (default: tofu/modules/bastion/files/secrets/<env>/id_ed25519)
#   BASTION_HOST           (default: bastion.<env>.yag.im)

set -euo pipefail
trap 'rc=$?; echo "ERROR: $BASH_SOURCE:$LINENO: \`${BASH_COMMAND}\` exited with $rc" >&2' ERR

# ---------------------------------------------------------------------------
# Parameters
# ---------------------------------------------------------------------------
INFRA_ENV="${INFRA_ENV:-${1:-}}"
case "$INFRA_ENV" in dev|prod) ;;
    *) echo "INFRA_ENV must be dev|prod, got: '${INFRA_ENV}'" >&2; exit 1;;
esac

# Master is always in us-east-1
CLUSTER_REGION="${CLUSTER_REGION:-us-east-1}"
ANSIBLE_USER="${ANSIBLE_USER:-debian}"
APPSTOR_REPLICAS="${APPSTOR_REPLICAS:-appstor0-us-west-1}"
VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-ansible/envs/${INFRA_ENV}/.vault_pwd}"
SSH_KEY_FILE="${SSH_KEY_FILE:-tofu/modules/bastion/files/secrets/${INFRA_ENV}/id_ed25519}"
BASTION_HOST="${BASTION_HOST:-bastion.${INFRA_ENV}.yag.im}"

# The master node is always appstor0 in us-east-1
MASTER_HOST="appstor0-us-east-1"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== initializing appstor master ==="
echo "  env:                  $INFRA_ENV"
echo "  master host:          $MASTER_HOST"
echo "  appstor replicas:     $APPSTOR_REPLICAS"
echo "  ansible user:         $ANSIBLE_USER"
echo

# ---------------------------------------------------------------------------
# Run appstor_master role
# ---------------------------------------------------------------------------
cd /workspaces/infra
export ANSIBLE_CONFIG="ansible/ansible.cfg"

echo "=== running appstor_master role on $MASTER_HOST ==="
ansible-playbook \
    --ssh-common-args "-o ServerAliveInterval=10 -o ProxyCommand='ssh -p 2207 -W %h:%p -q infra@${BASTION_HOST}'" \
    --user "$ANSIBLE_USER" \
    --key-file "$SSH_KEY_FILE" \
    --vault-password-file "$VAULT_PASSWORD_FILE" \
    -i "ansible/envs/${INFRA_ENV}/hosts_${CLUSTER_REGION}.yml" \
    -l "$MASTER_HOST" \
    -e "appstor_replicas=${APPSTOR_REPLICAS}" \
    --become \
    "ansible/playbooks/appstor_master.yml"

echo
echo "=== appstor master initialized ==="
echo "Verify lsyncd is running:"
echo "  systemctl status lsyncd"
echo "  docker ps  # should see appstor container"
echo "  tail -f /var/log/lsyncd/lsyncd.log"
