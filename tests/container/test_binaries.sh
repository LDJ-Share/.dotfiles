#!/usr/bin/env bash
# test_binaries.sh — verify all expected CLIs are on PATH and executable
set -uo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Binaries: core shell tools ==="
check_cmd nvim
check_cmd tmux
check_cmd zsh
check_cmd git
check_cmd curl
check_cmd wget
check_cmd jq
check_cmd fzf
check_cmd fd
check_cmd bat
check_cmd eza
check_cmd zoxide
check_cmd lazygit
check_cmd tv
check_cmd stow
check_cmd tree
check_cmd rg

echo ""
echo "=== Binaries: neovim version ==="
# Require nvim >= 0.11
NVIM_MINOR=$(nvim --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1 | cut -d. -f2 || echo "0")
check "nvim >= 0.11" [ "${NVIM_MINOR}" -ge 11 ]

echo ""
echo "=== Binaries: language runtimes ==="
check_cmd go
check_cmd cargo
check_cmd node
check_cmd npm
check_cmd bun
check_cmd pwsh
check_cmd dotnet
check_cmd python3
check_cmd pip3

echo ""
echo "=== Binaries: dev tools ==="
check_cmd gh
check_cmd kubectl
check_cmd kubectx
check_cmd kubens
check_cmd devcontainer
check_cmd just
check_cmd oh-my-posh

echo ""
echo "=== Binaries: AI tools ==="
check_cmd opencode
check_cmd pi

summary
