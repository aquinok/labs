#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_DIR="${1:-terraform/bootstrap}"
OUT_FILE="${2:-.backend.env}"

cd "$BOOTSTRAP_DIR"

BUCKET="$(terraform output -raw backend_bucket_name)"
REGION="$(terraform output -raw backend_region)"

cat >"../..//${OUT_FILE}" <<EOF
BACKEND_BUCKET=${BUCKET}
BACKEND_REGION=${REGION}
EOF

echo "Wrote ${OUT_FILE}: bucket=${BUCKET} region=${REGION}"
