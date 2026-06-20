#!/usr/bin/env bash
# Usage:
#   ./build_jukebox_image.sh [INFRA_ENV [CLUSTER_REGION]]
#
# Env overrides (take precedence over positional args):
#   INFRA_ENV      (default: dev)
#   CLUSTER_REGION (default: us-east-1)
#   FLAVOR, IMAGE_NAME, OPENRC
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$SCRIPT_DIR/../packer/images/jukebox/build.sh" "$@"
