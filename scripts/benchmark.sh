#!/bin/bash
set -euo pipefail

BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
ITERATIONS="${ITERATIONS:-3}"
ALL_MODELS=false
MODELS_ARG="${MODELS:-qwen3-coder-next}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) ALL_MODELS=true ;;
    --iterations) ITERATIONS="$2"; shift ;;
    --model) MODELS_ARG="$2"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

# Resolve model list
if [ "${ALL_MODELS}" = true ]; then
  mapfile -t MODELS_LIST < <(curl -sf "${BASE_URL}/api/tags" | jq -r '.models[].name')
  if [ "${#MODELS_LIST[@]}" -eq 0 ]; then
    echo "No models found at ${BASE_URL}/api/tags" >&2
    exit 1
  fi
else
  IFS=',' read -ra TEMP_LIST <<< "$MODELS_ARG"
  MODELS_LIST=()
  for m in "${TEMP_LIST[@]}"; do
    m="${m#"${m%%[![:space:]]*}"}"
    m="${m%"${m##*[![:space:]]}"}"
    [ -n "$m" ] && MODELS_LIST+=("$m")
  done
fi

echo "=== GPU info ==="
echo "Card:    NVIDIA RTX Pro 6000"
echo "VRAM:    96 GB (g4-standard-48)"
echo ""

bench_model() {
  local MODEL="$1"
  echo "=== ${MODEL} ==="

  local TPS_VALUES=()
  for _i in $(seq 1 "${ITERATIONS}"); do
    RESULT=$(curl -sf "${BASE_URL}/api/generate" \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"${MODEL}\",
        \"prompt\": \"Write a complete Terraform module for an AWS VPC with public and private subnets, NAT gateway, and route tables. Include all resource dependencies and outputs.\",
        \"options\": {\"num_ctx\": 32768, \"num_predict\": 400},
        \"stream\": false
      }")

    TPS=$(echo "${RESULT}" | jq '(.eval_count / .eval_duration * 1e9) | round')
    TOKENS=$(echo "${RESULT}" | jq '.eval_count')
    TPS_VALUES+=("${TPS}")
    echo "  [run] ${TPS} t/s  (${TOKENS} tokens)"
  done

  jq -n \
    --argjson values "$(printf '%s\n' "${TPS_VALUES[@]}" | jq -s '.')" \
    '($values | add / length) as $mean |
     "  Speed:      \($mean | round) t/s mean  (min \([$values | min] | first) / max \([$values | max] | first))"' \
    -r

  local PASS=0
  for _i in $(seq 1 "${ITERATIONS}"); do
    TC=$(curl -s "${BASE_URL}/api/chat" \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"${MODEL}\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Read the file /tmp/hello.py\"}],
        \"tools\": [{
          \"type\": \"function\",
          \"function\": {
            \"name\": \"read_file\",
            \"description\": \"Read a file from disk\",
            \"parameters\": {
              \"type\": \"object\",
              \"properties\": {\"path\": {\"type\": \"string\"}},
              \"required\": [\"path\"]
            }
          }
        }],
        \"stream\": false
      }" 2>/dev/null | jq '.message.tool_calls // [] | length' 2>/dev/null) || TC=0
    [ "${TC:-0}" -gt 0 ] && PASS=$((PASS + 1))
  done
  echo "  Tool calls: ${PASS}/${ITERATIONS}"
  echo ""
}

for MODEL in "${MODELS_LIST[@]}"; do
  bench_model "${MODEL}"
done
