#!/usr/bin/env bash
set -euo pipefail

# Repo root = parent of this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TF_DIR="${TF_DIR:-${REPO_ROOT}/terraform/envs/lab/us-east-1}"
INV="${INV:-${REPO_ROOT}/ansible/inventories/lab/hosts.yml}"
PB="${PB:-${REPO_ROOT}/ansible/playbooks/ubuntu24-cis.yml}"

cd "$TF_DIR"

# Pull the Secret ARN from Terraform output
SECRET_ARN="$(terraform output -raw ubuntu_password_secret_arn | tr -d '\r\n')"

# Fetch the plaintext password from Secrets Manager for sudo/become
export ANSIBLE_BECOME_PASS="$(
  aws secretsmanager get-secret-value \
    --secret-id "$SECRET_ARN" \
    --query SecretString \
    --output text
)"

exec ansible-playbook -i "$INV" "$PB" "$@"
