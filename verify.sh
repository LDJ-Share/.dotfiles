#!/usr/bin/env bash
# Verify all tools installed by setup.sh are present and working.
# Do not run as root (setup/common.sh will abort the source call).
# Usage: bash verify.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup/common.sh"

check() {
  local name="$1" cmd="$2"
  local version
  if version=$(eval "$cmd" 2>/dev/null); then
    echo -e "  ${GREEN}✓${NC} $name — $version"
  else
    echo -e "  ${RED}✗${NC} $name (not found)"
  fi
}

echo "Verifying installed tools..."
echo ""

# ── System ────────────────────────────────────────────────────────────────────
check "git"      "git --version"
check "curl"     "curl --version | head -1"
check "jq"       "jq --version"
check "stow"     "stow --version | head -1"
check "tmux"     "tmux -V"
check "zsh"      "zsh --version"
check "rg"       "rg --version | head -1"
check "fd"       "fd --version"
check "fzf"      "fzf --version"
check "bat"      "bat --version"
check "tree"     "tree --version | head -1"
check "unzip"    "unzip -v | head -1"
check "wget"     "wget --version | head -1"

# ── Docker ────────────────────────────────────────────────────────────────────
check "docker"   "docker --version"

# ── Neovim ───────────────────────────────────────────────────────────────────
check "nvim"     "nvim --version | head -1"

# ── Shell tools ───────────────────────────────────────────────────────────────
check "zoxide"   "zoxide --version"
check "eza"      "eza --version | sed -n '2p'"
check "wezterm"  "wezterm --version"
check "lazygit"  "lazygit --version"
check "tv"       "tv --version"

# ── Kubernetes ────────────────────────────────────────────────────────────────
check "kubectl"  "kubectl version --client | head -1"
check "kubectx"  "command -v kubectx"
check "kubens"   "command -v kubens"

# ── Languages ────────────────────────────────────────────────────────────────
check "go"       "go version"
check "cargo"    "cargo --version"
check "node"     "node --version"
check "bun"      "bun --version"
check "dotnet"   "dotnet --version"
check "pwsh"     "pwsh --version"

# ── Dev tools ────────────────────────────────────────────────────────────────
check "devcontainer" "devcontainer --version"

# ── AI tools ─────────────────────────────────────────────────────────────────
check "pi"            "pi --version"

echo ""
echo "Done."
