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
check "pi --help exits 0" pi --help

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
echo "=== Pi: packages pre-installed (no runtime download needed) ==="
# Pi downloads packages listed in settings.json on first run unless they are
# pre-installed. We install them explicitly during the Docker build so the
# container starts instantly without any lazy package fetching.
# Verify via npm package directories under the user's npm prefix.
check_dir "${NPM_PREFIX}/lib/node_modules/@cmcconomy"

summary
