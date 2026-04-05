#!/usr/bin/env bash
# test_tmux.sh — verify TPM and all configured plugins are pre-installed
set -uo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

PLUGINS_DIR="${HOME}/.tmux/plugins"

echo "=== tmux: binary ==="
check_cmd tmux

echo ""
echo "=== tmux: TPM installed ==="
check_dir "${PLUGINS_DIR}/tpm"
check_file "${PLUGINS_DIR}/tpm/tpm"
check_file "${PLUGINS_DIR}/tpm/scripts/install_plugins.sh"

echo ""
echo "=== tmux: plugins installed ==="
# All @plugin entries from tmux.conf (directory name = last path segment before any #version)
EXPECTED_PLUGINS=(
  tmux-sensible
  tmux-yank
  tmux-resurrect
  tmux-continuum
  tmux-thumbs
  tmux-fzf
  tmux-fzf-url
  tmux
  tmux-sessionx
  tmux-floax
)

for plugin in "${EXPECTED_PLUGINS[@]}"; do
  check_dir "${PLUGINS_DIR}/${plugin}"
done

echo ""
echo "=== tmux: config is stowed ==="
check_file "${HOME}/.config/tmux/tmux.conf"
check_file "${HOME}/.config/tmux/tmux.reset.conf"

summary
