#!/usr/bin/env bash
# test_configs.sh — verify all dotfiles are stowed and all Ollama URLs are correct
set -uo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

OLLAMA_HOST="10\.10\.10\.10:11434"
BAD_PATTERNS=("127\.0\.0\.1" "localhost")

echo "=== Configs: dotfiles stowed ==="
check_file "${HOME}/.config/nvim/init.lua"
check_file "${HOME}/.config/tmux/tmux.conf"
check_file "${HOME}/.zshrc"
check_file "${HOME}/.pi/agent/models.json"
check_file "${HOME}/.pi/agent/settings.json"
check_file "${HOME}/.opencode/config.json"
check_file "${HOME}/.opencode/oh-my-opencode.json"

echo ""
echo "=== Configs: Ollama URL in Pi models.json ==="
check_contains "models.json → OllamaNet host" \
  "${HOME}/.pi/agent/models.json" "${OLLAMA_HOST}"
for pat in "${BAD_PATTERNS[@]}"; do
  check_not_contains "models.json → no ${pat}" \
    "${HOME}/.pi/agent/models.json" "${pat}"
done

echo ""
echo "=== Configs: Ollama URL in OpenCode config.json ==="
check_contains "opencode config.json → OllamaNet host" \
  "${HOME}/.opencode/config.json" "${OLLAMA_HOST}"
for pat in "${BAD_PATTERNS[@]}"; do
  check_not_contains "opencode config.json → no ${pat}" \
    "${HOME}/.opencode/config.json" "${pat}"
done

echo ""
echo "=== Configs: default model set ==="
check_contains "Pi default model set" \
  "${HOME}/.pi/agent/settings.json" "defaultModel"
check_contains "OpenCode model set" \
  "${HOME}/.opencode/config.json" "\"model\""

echo ""
echo "=== Configs: shell ==="
# zsh should be the default shell for the container user
check "default shell is zsh" \
  bash -c 'getent passwd dev | grep -q "zsh"'

summary
