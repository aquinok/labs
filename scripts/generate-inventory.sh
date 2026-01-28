#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TF_DIR="${TF_DIR:-${REPO_ROOT}/terraform/envs/lab/us-east-1}"
TEMPLATE="${REPO_ROOT}/ansible/inventories/lab/hosts.yml.tmpl"
OUTPUT="${REPO_ROOT}/ansible/inventories/lab/hosts.yml"
OUTPUT_TMP="${OUTPUT}.tmp"

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

# Basic sanity checks
[[ -d "$TF_DIR" ]] || { echo "ERROR: TF_DIR not found: $TF_DIR" >&2; exit 1; }
[[ -f "$TEMPLATE" ]] || { echo "ERROR: Template not found: $TEMPLATE" >&2; exit 1; }

cd "$TF_DIR"

# Make sure Terraform is usable here
if [[ ! -d ".terraform" ]]; then
  echo "NOTE: Terraform not initialized in $TF_DIR (no .terraform/). Run 'make tf-init' first." >&2
fi

# Pull Terraform outputs as JSON (with friendly errors)
if ! IPS_JSON="$(terraform output -json public_ips 2>/dev/null)"; then
  echo "ERROR: Terraform output 'public_ips' not found. Did you run apply in $TF_DIR?" >&2
  exit 1
fi

if ! NAMES_JSON="$(terraform output -json instance_names 2>/dev/null)"; then
  echo "ERROR: Terraform output 'instance_names' not found. Did you run apply in $TF_DIR?" >&2
  exit 1
fi

# Build hosts block
HOSTS_BLOCK="$(
  IPS_JSON="$IPS_JSON" NAMES_JSON="$NAMES_JSON" SSH_KEY="$SSH_KEY" python3 - <<'PY'
import json, os, sys

ips = json.loads(os.environ["IPS_JSON"])
names = json.loads(os.environ["NAMES_JSON"])
ssh_key = os.environ["SSH_KEY"]

if not isinstance(ips, list) or not isinstance(names, list):
    print("ERROR: Expected 'public_ips' and 'instance_names' to be JSON lists.", file=sys.stderr)
    sys.exit(1)

if len(ips) != len(names):
    print(f"ERROR: Count mismatch: {len(names)} names vs {len(ips)} IPs", file=sys.stderr)
    sys.exit(1)

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

# Render template -> output atomically
HOSTS_BLOCK="$HOSTS_BLOCK" TEMPLATE="$TEMPLATE" OUTPUT_TMP="$OUTPUT_TMP" python3 - <<'PY'
import os

tmpl_path = os.environ["TEMPLATE"]
out_tmp = os.environ["OUTPUT_TMP"]

tmpl = open(tmpl_path, "r", encoding="utf-8").read()
out = tmpl.replace("${HOSTS_BLOCK}", os.environ["HOSTS_BLOCK"])

open(out_tmp, "w", encoding="utf-8").write(out)
PY

mv -f "$OUTPUT_TMP" "$OUTPUT"
echo "[+] Inventory written to $OUTPUT"
