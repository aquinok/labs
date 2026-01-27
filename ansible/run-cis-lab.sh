#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-$HOME/labs/terraform/envs/lab/us-east-1}"
INV="${INV:-inventories/lab/hosts.yml}"
PB="${PB:-playbooks/ubuntu24-cis.yml}"

cd "$TF_DIR"
SECRET_ARN="$(terraform output -raw ubuntu_password_secret_arn | tr -d '\r\n')"

export ANSIBLE_BECOME_PASS="$(
  aws secretsmanager get-secret-value \
    --secret-id "$SECRET_ARN" \
    --query SecretString \
    --output text
)"

cd "$HOME/labs/ansible"
exec ansible-playbook -i "$INV" "$PB" "$@"
