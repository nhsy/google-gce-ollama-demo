#!/bin/bash
set -euo pipefail

BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
MODEL="${MODEL:-qwen3-coder-next}"

SCRIPT_START=$(date +%s%N)

echo "=== Version ==="
T0=$(date +%s%N)
curl -sf "${BASE_URL}/api/version" | jq .
echo "Duration: $(( ($(date +%s%N) - T0) / 1000000 ))ms"

echo ""
echo "=== Loaded models ==="
T0=$(date +%s%N)
curl -sf "${BASE_URL}/api/tags" | jq '[.models[] | {name, size}]'
echo "Duration: $(( ($(date +%s%N) - T0) / 1000000 ))ms"

format_duration() {
  local ms=$1
  local secs=$(( ms / 1000 ))
  local mins=$(( secs / 60 ))
  local rem_secs=$(( secs % 60 ))
  if [[ ${ms} -lt 1000 ]]; then
    echo "${ms}ms"
  elif [[ ${mins} -gt 0 ]]; then
    echo "${mins}m ${rem_secs}s"
  else
    echo "${rem_secs}s"
  fi
}

echo ""
echo "=== Generate test (model: ${MODEL}) ==="
T0=$(date +%s%N)
START_TIME=$(date "+%H:%M:%S")
RESPONSE=$(curl -sf "${BASE_URL}/api/generate" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL}\",
    \"prompt\": \"Say hello in one sentence.\",
    \"stream\": false
  }")
ELAPSED_MS=$(( ($(date +%s%N) - T0) / 1000000 ))
END_TIME=$(date "+%H:%M:%S")
echo "Response: $(echo "${RESPONSE}" | jq -r '.response')"
echo "Start:    ${START_TIME}"
echo "End:      ${END_TIME}"
echo "Duration: $(format_duration "${ELAPSED_MS}")"

echo ""
TOTAL_MS=$(( ($(date +%s%N) - SCRIPT_START) / 1000000 ))
echo "Total: $(format_duration "${TOTAL_MS}")"
