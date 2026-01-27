#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TF_DIR="${TF_DIR:-${REPO_ROOT}/terraform/envs/lab/us-east-1}"
TEMPLATE="${REPO_ROOT}/ansible/inventories/lab/hosts.yml.tmpl"
OUTPUT="${REPO_ROOT}/ansible/inventories/lab/hosts.yml"

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

cd "$TF_DIR"

# Pull Terraform outputs as JSON
IPS_JSON="$(terraform output -json instance_public_ips)"
NAMES_JSON="$(terraform output -json instance_names)"

# Build hosts block (ensure env vars are available to python)
HOSTS_BLOCK="$(
  IPS_JSON="$IPS_JSON" NAMES_JSON="$NAMES_JSON" SSH_KEY="$SSH_KEY" python3 - <<'PY'
import json, os

ips = json.loads(os.environ["IPS_JSON"])
names = json.loads(os.environ["NAMES_JSON"])
ssh_key = os.environ["SSH_KEY"]

lines = []
for name, ip in zip(names, ips):
    lines.append(f"        {name}:")
    lines.append(f"          ansible_host: {ip}")
    lines.append(f"          ansible_user: ubuntu")
    lines.append(f"          ansible_ssh_private_key_file: {ssh_key}")
    lines.append(f"          ansible_python_interpreter: /usr/bin/python3")
print("\n".join(lines))
PY
)"

# Render template -> output
HOSTS_BLOCK="$HOSTS_BLOCK" python3 - <<PY
import os
tmpl = open("${TEMPLATE}", "r", encoding="utf-8").read()
out = tmpl.replace("\${HOSTS_BLOCK}", os.environ["HOSTS_BLOCK"])
open("${OUTPUT}", "w", encoding="utf-8").write(out)
PY

echo "✔ Inventory written to $OUTPUT"