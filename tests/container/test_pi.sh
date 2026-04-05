#!/usr/bin/env bash
# test_pi.sh — verify Pi coding agent is installed, initialized, and configured
set -uo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

PI_MODELS="${HOME}/.pi/agent/models.json"
PI_SETTINGS="${HOME}/.pi/agent/settings.json"
# Pi uses a local npm prefix; resolve it at test time
NPM_PREFIX=$(npm config get prefix 2>/dev/null || echo "${HOME}/.local")
PI_PKG_DIR="${NPM_PREFIX}/lib/node_modules/@mariozechner/pi-coding-agent"
QWEN_PKG_DIR="${NPM_PREFIX}/lib/node_modules/@cmcconomy/pi-qwen-tool-parser"

echo "=== Pi: binary ==="
check_cmd pi
check "pi --version exits 0" pi --version

echo ""
echo "=== Pi: config files ==="
check_file "${PI_MODELS}"
check_file "${PI_SETTINGS}"

echo ""
echo "=== Pi: Ollama URL ==="
check_contains "models.json uses OllamaNet host" \
  "${PI_MODELS}" "10\.10\.10\.10:11434"
check_not_contains "models.json does not use localhost" \
  "${PI_MODELS}" "127\.0\.0\.1"
check_not_contains "models.json does not use localhost (hostname)" \
  "${PI_MODELS}" "localhost"

echo ""
echo "=== Pi: npm packages installed ==="
check_dir "${PI_PKG_DIR}"
check_dir "${QWEN_PKG_DIR}"

echo ""
echo "=== Pi: settings packages listed ==="
# Verify settings.json references the qwen tool parser package
check_contains "settings.json references qwen-tool-parser" \
  "${PI_SETTINGS}" "@cmcconomy/pi-qwen-tool-parser"

echo ""
echo "=== Pi: first-run initialization ==="
# pi --print sends a prompt and exits; use a trivial prompt to confirm
# the agent starts and responds without downloading anything at runtime
check "pi --print responds without network fetch" \
  bash -c 'echo "hello" | timeout 30 pi --print 2>/dev/null | grep -q "."'

summary
