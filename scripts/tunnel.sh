#!/bin/bash
set -euo pipefail

INSTANCE="${1:?Usage: tunnel.sh <instance-name> <zone> <project-id> [local-port]}"
ZONE="${2:?Usage: tunnel.sh <instance-name> <zone> <project-id> [local-port]}"
PROJECT="${3:?Usage: tunnel.sh <instance-name> <zone> <project-id> [local-port]}"
LOCAL_PORT="${4:-11434}"
RETRY_INTERVAL="${5:-10}"

echo "IAP tunnel: localhost:${LOCAL_PORT} -> ${INSTANCE}:11434 (${ZONE})"
echo "Press Ctrl+C to stop."

MAX_RETRIES=3
attempt=0
until gcloud compute start-iap-tunnel "${INSTANCE}" 11434 \
    --local-host-port="localhost:${LOCAL_PORT}" \
    --zone="${ZONE}" \
    --project="${PROJECT}"; do
  attempt=$(( attempt + 1 ))
  if [ "${attempt}" -ge "${MAX_RETRIES}" ]; then
    echo "Tunnel failed after ${MAX_RETRIES} attempts. Giving up."
    exit 1
  fi
  echo "Tunnel connection failed (attempt ${attempt}/${MAX_RETRIES}), retrying in ${RETRY_INTERVAL}s..."
  sleep "${RETRY_INTERVAL}"
done
