#!/usr/bin/env bash
set -uo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

TEMPLATE_DIR="${TEMPLATES_DIR:-/workspace/templates}/workspace-template"
COMPOSE_FILE="${TEMPLATE_DIR}/.devcontainer/docker-compose.yml"
DEVCONTAINER_FILE="${TEMPLATE_DIR}/.devcontainer/devcontainer.json"
HELPER_FILE="${TEMPLATE_DIR}/.devcontainer/configure-ollama-endpoint.sh"
ENV_FILE="${TEMPLATE_DIR}/.env.example"

echo "=== Workspace template: files exist ==="
check_dir "${TEMPLATE_DIR}"
check_file "${COMPOSE_FILE}"
check_file "${DEVCONTAINER_FILE}"
check_file "${HELPER_FILE}"
check_file "${ENV_FILE}"

echo ""
echo "=== Workspace template: compose contract ==="
check_contains "template keeps dev-env service" "${COMPOSE_FILE}" "dev-env"
check_contains "template keeps ollama service" "${COMPOSE_FILE}" "ollama"
check_contains "template keeps ai-net network" "${COMPOSE_FILE}" "ai-net"
check_contains "template keeps workspace mount" "${COMPOSE_FILE}" "..:/workspace"
check_contains "template defaults to compose-internal ollama" "${COMPOSE_FILE}" "http://ollama:11434"
check_contains "template documents host fallback" "${COMPOSE_FILE}" "10.10.10.10:11434"
check_contains "template documents cuda prep" "${COMPOSE_FILE}" "cuda-prep"
check_contains "template documents import workflow" "${COMPOSE_FILE}" "image-import"

echo ""
echo "=== Workspace template: devcontainer contract ==="
check "template devcontainer JSON stays aligned" python3 -c "import json; d=json.load(open('${DEVCONTAINER_FILE}')); assert d['service']=='dev-env'; assert d['workspaceFolder']=='/workspace'; assert d['remoteUser']=='dev'; assert d['runServices']==['dev-env','ollama']"

echo ""
echo "=== Workspace template: override files ==="
check_contains "template env example includes local dev image" "${ENV_FILE}" "dotfiles-dev-env:local"
check_contains "template env example includes local ollama image" "${ENV_FILE}" "ollama/ollama:0.20.3"
check_contains "template helper keeps default endpoint" "${HELPER_FILE}" "http://ollama:11434"
check_contains "template helper documents host override" "${HELPER_FILE}" "10.10.10.10:11434"

summary
