#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TF_DIR="${TF_DIR:-${REPO_ROOT}/terraform/envs/lab/us-east-1}"
TEMPLATE="${REPO_ROOT}/ansible/inventories/lab/hosts.yml.tmpl"
OUTPUT="${REPO_ROOT}/ansible/inventories/lab/hosts.yml"

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

cd "$TF_DIR"

INSTANCE_IP="$(terraform output -raw instance_public_ip)"

sed \
  -e "s|\${INSTANCE_IP}|${INSTANCE_IP}|g" \
  -e "s|\${SSH_KEY}|${SSH_KEY}|g" \
  "$TEMPLATE" >"$OUTPUT"

echo "✔ Inventory written to $OUTPUT"
