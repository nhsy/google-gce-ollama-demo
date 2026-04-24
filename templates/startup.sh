#!/bin/bash
set -euo pipefail

# GCE startup scripts run without $HOME set; Ollama's envconfig panics without it.
export HOME=/root

METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"

get_metadata() {
  curl -sf "${METADATA_URL}/$1" -H "Metadata-Flavor: Google"
}

OLLAMA_MODELS=$(get_metadata "ollama-model")
RAMDISK_GB=$(get_metadata "ramdisk-size-gb")
GCS_BUCKET=$(get_metadata "gcs-model-bucket")
RAMDISK_DIR="/mnt/ramdisk"
LOG_FILE="/var/log/ollama-startup.log"

log() { echo "[startup $(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== GCE Ollama startup ==="
log "Models: $OLLAMA_MODELS | RAM disk: ${RAMDISK_GB}G | Cache: gs://$GCS_BUCKET"

# ── 1. Install Dependencies ──────────────────────────────────────────────────
log "Checking dependencies..."
apt-get update
apt-get install -y jq curl

# ── 2. Install Ollama ─────────────────────────────────────────────────────────
if ! command -v ollama &>/dev/null; then
  log "Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
  log "Ollama installed"
else
  log "Ollama already installed"
fi

# ── 3. Mount RAM disk at /mnt/ramdisk ────────────────────────────────────────
mkdir -p "$RAMDISK_DIR"

if mountpoint -q "$RAMDISK_DIR"; then
  log "RAM disk already mounted at $RAMDISK_DIR"
else
  log "Mounting ${RAMDISK_GB}G tmpfs at $RAMDISK_DIR"
  mount -t tmpfs -o "size=${RAMDISK_GB}G" tmpfs "$RAMDISK_DIR"
fi

# ── 4. Restore model cache from GCS ──────────────────────────────────────────
# No-op on first run (empty bucket). On subsequent starts, restores a manually
# cached model; rsync skips unchanged blobs so it's fast intra-region.
log "Restoring model cache from gs://$GCS_BUCKET ..."
if gcloud storage rsync -r "gs://$GCS_BUCKET/" "$RAMDISK_DIR/"; then
  log "GCS restore complete"
else
  log "GCS restore skipped (bucket may be empty or unreachable)"
fi

chown -R ollama:ollama "$RAMDISK_DIR"

# ── 5. Configure Ollama to use the RAM disk ───────────────────────────────────
mkdir -p /etc/systemd/system/ollama.service.d/
cat > /etc/systemd/system/ollama.service.d/override.conf <<EOF
[Service]
Environment="OLLAMA_MODELS=$RAMDISK_DIR"
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q4_0"
Environment="OLLAMA_NUM_CTX=65536"
Environment="OLLAMA_KEEP_ALIVE=-1"
Environment="OLLAMA_TMPDIR=/tmp"
EOF

# ── 6. Start Ollama ───────────────────────────────────────────────────────────
log "Starting Ollama service..."
systemctl daemon-reload
systemctl enable ollama
systemctl restart ollama

# ── 7. Wait for Ollama API ────────────────────────────────────────────────────
log "Waiting for Ollama API..."
READY=false
for _ in {1..60}; do
  if curl -sf http://localhost:11434/api/version >/dev/null 2>&1; then
    READY=true
    break
  fi
  sleep 5
done

if [ "$READY" = false ]; then
  log "ERROR: Ollama API did not become ready after 5 minutes"
  exit 1
fi
log "Ollama API ready"

# ── 8. Ensure models are available ──────────────────────────────────────────────
MODEL_COUNT=$(echo "$OLLAMA_MODELS" | jq '. | length')
log "Checking ${MODEL_COUNT} model(s)..."

MODELS_PULLED=false
for MODEL in $(echo "$OLLAMA_MODELS" | jq -r '.[]'); do
  if ollama list | grep -qF "$MODEL"; then
    log "Model already loaded: $MODEL"
  else
    log "Model not in cache — pulling from registry: $MODEL"
    ollama pull "$MODEL"
    log "Pull complete: $MODEL"
    MODELS_PULLED=true
  fi
done

# ── 9. Sync back to GCS if we pulled new models ──────────────────────────────
if [ "$MODELS_PULLED" = true ]; then
  log "Syncing model cache back to gs://$GCS_BUCKET ..."
  if gcloud storage rsync -r "$RAMDISK_DIR/" "gs://$GCS_BUCKET/"; then
    log "GCS sync complete"
  else
    log "WARNING: GCS sync failed"
  fi
fi

log "Startup complete"
