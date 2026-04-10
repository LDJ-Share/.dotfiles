#!/usr/bin/env bash
# run_all.sh — run all container test scripts and report aggregate results
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_FAIL=0

TESTS=(
  test_binaries.sh
  test_neovim.sh
  test_opencode.sh
  test_pi.sh
  test_tmux.sh
  test_configs.sh
  test_export_scripts.sh
)

for test in "${TESTS[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Running: ${test}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if bash "${SCRIPT_DIR}/${test}"; then
    echo "=> ${test}: PASSED"
  else
    echo "=> ${test}: FAILED"
    ((TOTAL_FAIL++)) || true
  fi
  echo ""
done

echo "════════════════════════════════════════════════"
if [ "${TOTAL_FAIL}" -eq 0 ]; then
  echo "All container tests passed."
else
  echo "${TOTAL_FAIL} test file(s) failed."
  exit 1
fi
