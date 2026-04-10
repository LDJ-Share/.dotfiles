#!/usr/bin/env bash
set -euo pipefail

# Keep Pi and OpenCode aligned with whichever endpoint this copied template uses.
# Default path: compose-internal Ollama at http://ollama:11434
# Optional host fallback: export OLLAMA_HOST=http://10.10.10.10:11434 before `docker compose up`

OLLAMA_HOST_VALUE="${OLLAMA_HOST:-http://ollama:11434}"
if [[ "${OLLAMA_HOST_VALUE}" != http://* && "${OLLAMA_HOST_VALUE}" != https://* ]]; then
  OLLAMA_HOST_VALUE="http://${OLLAMA_HOST_VALUE}"
fi
OLLAMA_BASE_URL="${OLLAMA_HOST_VALUE%/}/v1"

PI_CONFIG="${HOME}/.pi/agent/models.json"
OPENCODE_CONFIG="${HOME}/.opencode/config.json"

tmp_pi=$(mktemp)
jq --arg base_url "${OLLAMA_BASE_URL}" '.providers.ollama.baseUrl = $base_url' "${PI_CONFIG}" > "${tmp_pi}"
mv "${tmp_pi}" "${PI_CONFIG}"

tmp_opencode=$(mktemp)
jq --arg base_url "${OLLAMA_BASE_URL}" '.provider.ollama.options.baseURL = $base_url' "${OPENCODE_CONFIG}" > "${tmp_opencode}"
mv "${tmp_opencode}" "${OPENCODE_CONFIG}"
