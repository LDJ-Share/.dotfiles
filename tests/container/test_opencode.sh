#!/usr/bin/env bash
# test_opencode.sh — verify opencode and oh-my-opencode are fully initialized
set -uo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

OPENCODE_CONFIG="${HOME}/.opencode/config.json"
OMO_CONFIG="${HOME}/.opencode/oh-my-opencode.json"

echo "=== OpenCode: binary ==="
check_cmd opencode
check "opencode --version exits 0" opencode --version

echo ""
echo "=== OpenCode: config files ==="
check_file "${OPENCODE_CONFIG}"
check_file "${OMO_CONFIG}"

echo ""
echo "=== OpenCode: oh-my-opencode installed ==="
# oh-my-opencode install writes itself into the opencode config
check_contains "config references oh-my-opencode" \
  "${OPENCODE_CONFIG}" "oh-my-opencode"

echo ""
echo "=== OpenCode: oh-my-opencode agents configured ==="
# All agents defined in oh-my-opencode.json must be present
EXPECTED_AGENTS=(
  hephaestus
  oracle
  librarian
  explore
  multimodal-looker
  prometheus
  metis
  momus
  atlas
  sisyphus-junior
)
for agent in "${EXPECTED_AGENTS[@]}"; do
  check_contains "agent: ${agent}" "${OMO_CONFIG}" "\"${agent}\""
done

echo ""
echo "=== OpenCode: oh-my-opencode categories configured ==="
EXPECTED_CATEGORIES=(
  visual-engineering
  ultrabrain
  deep
  artistry
  quick
  writing
)
for cat in "${EXPECTED_CATEGORIES[@]}"; do
  check_contains "category: ${cat}" "${OMO_CONFIG}" "\"${cat}\""
done

echo ""
echo "=== OpenCode: Ollama URL ==="
check_contains "config uses OllamaNet host" \
  "${OPENCODE_CONFIG}" "10\.10\.10\.10:11434"
check_not_contains "config does not use localhost" \
  "${OPENCODE_CONFIG}" "127\.0\.0\.1"
check_not_contains "config does not use localhost (hostname)" \
  "${OPENCODE_CONFIG}" "localhost"

summary
