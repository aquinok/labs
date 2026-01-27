#!/usr/bin/env bash
set -euo pipefail

BUCKET="${1:-}"
if [[ -z "$BUCKET" ]]; then
  echo "Usage: $0 <bucket-name>"
  exit 1
fi

echo "Purging ALL objects + versions + delete markers from s3://$BUCKET ..."

KEY_MARKER=""
VER_MARKER=""

while true; do
  set +e
  if [[ -n "$KEY_MARKER" && -n "$VER_MARKER" ]]; then
    PAGE_JSON="$(aws s3api list-object-versions \
      --bucket "$BUCKET" \
      --key-marker "$KEY_MARKER" \
      --version-id-marker "$VER_MARKER" \
      --output json 2>/dev/null)"
  else
    PAGE_JSON="$(aws s3api list-object-versions \
      --bucket "$BUCKET" \
      --output json 2>/dev/null)"
  fi
  rc=$?
  set -e

  if [[ $rc -ne 0 || -z "${PAGE_JSON}" ]]; then
    echo "Could not list versions for bucket '$BUCKET' (bucket may not exist or AWS CLI error)."
    exit 0
  fi

  read -r COUNT DELETE_JSON NEXT_KEY NEXT_VER < <(
    python3 - <<'PY'
import json, sys
data = json.loads(sys.stdin.read())

objs = []
for v in data.get("Versions", []):
    objs.append({"Key": v["Key"], "VersionId": v["VersionId"]})
for m in data.get("DeleteMarkers", []):
    objs.append({"Key": m["Key"], "VersionId": m["VersionId"]})

count = len(objs)
delete_payload = json.dumps({"Objects": objs}, separators=(",", ":")) if count else ""

next_key = data.get("NextKeyMarker") or ""
next_ver = data.get("NextVersionIdMarker") or ""

print(count, delete_payload, next_key, next_ver)
PY
    <<<"$PAGE_JSON"
  )

  if [[ "${COUNT:-0}" -gt 0 ]]; then
    aws s3api delete-objects --bucket "$BUCKET" --delete "$DELETE_JSON" >/dev/null
    echo "Deleted batch of $COUNT versions/markers..."
  fi

  if [[ -z "${NEXT_KEY:-}" || -z "${NEXT_VER:-}" ]]; then
    break
  fi

  KEY_MARKER="$NEXT_KEY"
  VER_MARKER="$NEXT_VER"
done

echo "Purge complete."
