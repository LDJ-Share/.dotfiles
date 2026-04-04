#!/usr/bin/env bash
# Ubuntu 24.04 dotfiles bootstrap script (consolidated)
# Usage: bash setup.sh [username] [dotfiles-dir] [--only m1 m2...] [--skip m1 m2...]

set -euo pipefail

# ── Color codes ──────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── Utility functions ────────────────────────────────────────────────────────
log() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}WARN:${NC} $1"; }
contains() {
  local needle="$1"
  shift
  local e
  for e in "$@"; do [[ "$e" == "$needle" ]] && return 0; done
  return 1
}
# Quiet apt install — suppresses download progress and dpkg staircase output
apt_install() {
  sudo apt-get install -y -qq \
    -o Dpkg::Progress-Fancy=0 \
    -o APT::Color=0 \
    "$@" 2>&1 | grep -v "^$" || true
}
apt_update() {
  sudo apt-get update -qq 2>&1 | grep -v "^$" || true
}

# ── Parse positional args (must come before any flags) ────────────────────────
USERNAME="krawlz"
DOTFILES_DIR="$HOME/.dotfiles"

if [[ "${1:-}" != --* && -n "${1:-}" ]]; then
  USERNAME="$1"
  shift
fi
if [[ "${1:-}" != --* && -n "${1:-}" ]]; then
  DOTFILES_DIR="$1"
  shift
fi

# ── Parse --only / --skip ────────────────────────────────────────────────────
ONLY=()
SKIP=()
while [[ $# -gt 0 ]]; do
  case "$1" in
  --only)
    shift
    while [[ $# -gt 0 && "$1" != --* ]]; do
      ONLY+=("$1")
      shift
    done
    ;;
  --skip)
    shift
    while [[ $# -gt 0 && "$1" != --* ]]; do
      SKIP+=("$1")
      shift
    done
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ ${#ONLY[@]} -gt 0 && ${#SKIP[@]} -gt 0 ]]; then
  echo "Error: --only and --skip are mutually exclusive." >&2
  exit 1
fi

# ── Export for module functions ──────────────────────────────────────────────
export USERNAME
export DOTFILES_DIR

# ── Suppress apt/dpkg interactive prompts and fancy progress output ───────────
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# ── Root check ───────────────────────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
  echo "Run as a regular user with sudo access, not root."
  exit 1
fi

# ── Sudo keepalive ───────────────────────────────────────────────────────────
sudo -v 2>/dev/null || true
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: system
# ═════════════════════════════════════════════════════════════════════════════
module_system() {
  log "━━ Running module: system ━━"

  log "Updating apt and installing base packages..."
  apt_update
  apt_install \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    direnv \
    fd-find \
    fzf \
    git \
    gnupg \
    jq \
    lsb-release \
    nmap \
    neovim \
    python3 \
    python3-pip \
    ranger \
    ripgrep \
    software-properties-common \
    stow \
    tar \
    tmux \
    tree \
    unzip \
    wget \
    zip \
    ffmpeg \
    gitk \
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting

  # Install python tools needed by neovim mason
  pip3 install pylint isort black

  # fd-find ships as 'fdfind' on Ubuntu; add symlink
  if ! command -v fd &>/dev/null; then
    sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
  fi

  # ── fzf (upgrade if apt version is too old for fzf-lua)
  # apt ships 0.44 which lacks the transform() action required by fzf-lua >= 0.53
  FZF_MIN="0.53"
  FZF_CUR=$(fzf --version 2>/dev/null | awk '{print $1}')
  if ! printf '%s\n%s' "$FZF_MIN" "$FZF_CUR" | sort -V -C 2>/dev/null; then
    log "Upgrading fzf (apt has $FZF_CUR, need >= $FZF_MIN)..."
    FZF_ASSET=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest |
      jq -r '.assets[] | select(.name | test("linux_amd64\\.tar\\.gz")) | .browser_download_url' | head -1)
    curl -sSfL "$FZF_ASSET" | tar -xz -C /tmp
    sudo mv /tmp/fzf /usr/local/bin/fzf
    log "fzf $(fzf --version) installed."
  else
    warn "fzf $FZF_CUR is sufficient, skipping upgrade."
  fi

  # ── Bat (better cat)
  if ! command -v bat &>/dev/null; then
    log "Installing Bat..."
    apt_install bat
    # Ubuntu ships as 'batcat'
    if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
      sudo ln -sf "$(which batcat)" /usr/local/bin/bat
    fi
  else
    warn "Bat already installed, skipping."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: docker
# ═════════════════════════════════════════════════════════════════════════════
module_docker() {
  log "━━ Running module: docker ━━"

  if ! command -v docker &>/dev/null; then
    log "Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
      sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
		https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    apt_update
    apt_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -aG docker "$USER"
    log "Docker installed. Log out and back in for group membership to take effect."
  else
    warn "Docker already installed, skipping."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: podman
# ═════════════════════════════════════════════════════════════════════════════
module_podman() {
  log "━━ Running module: podman ━━"

  # ── Ensure flatpak is installed
  if ! command -v flatpak &>/dev/null; then
    log "Installing Flatpak..."
    apt_install flatpak
  fi

  # ── Add Flathub remote (idempotent)
  if ! flatpak remotes | grep -q flathub; then
    log "Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi

  # ── Install Podman
  if ! command -v podman &>/dev/null; then
    log "Installing Podman..."
    apt_install podman
  fi

  # ── Install Podman Desktop
  if ! flatpak list --app | grep -q "io.podman_desktop.PodmanDesktop"; then
    log "Installing Podman Desktop..."
    flatpak install --noninteractive flathub io.podman_desktop.PodmanDesktop
  else
    warn "Podman Desktop already installed, skipping."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: neovim
# ═════════════════════════════════════════════════════════════════════════════
module_neovim() {
  log "━━ Running module: neovim ━━"

  NVIM_VER=$(nvim --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1 || echo "0.0")
  NVIM_MAJOR=$(echo "$NVIM_VER" | cut -d. -f1)
  NVIM_MINOR=$(echo "$NVIM_VER" | cut -d. -f2)
  if [ "$NVIM_MAJOR" -eq 0 ] && [ "$NVIM_MINOR" -lt 11 ]; then
    log "Installing latest Neovim via AppImage..."
    NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage"
    curl -Lo /tmp/nvim.appimage "$NVIM_URL"
    chmod +x /tmp/nvim.appimage
    sudo mv /tmp/nvim.appimage /usr/local/bin/nvim
    log "Neovim $(nvim --version | head -1) installed."
  else
    log "Neovim $NVIM_VER is sufficient, skipping upgrade."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: shell
# ═════════════════════════════════════════════════════════════════════════════
module_shell() {
  log "━━ Running module: shell ━━"

  # ── Zoxide (smart cd)
  if ! command -v zoxide &>/dev/null; then
    log "Installing Zoxide..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  else
    warn "Zoxide already installed, skipping."
  fi

  # ── Eza (modern ls)
  if ! command -v eza &>/dev/null; then
    log "Installing Eza..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc |
      sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" |
      sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    apt_update
    apt_install eza
  else
    warn "Eza already installed, skipping."
  fi

  # ── WezTerm
  if ! command -v wezterm &>/dev/null; then
    log "Installing WezTerm..."
    curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
    apt_update && apt_install wezterm
  else
    warn "WezTerm already installed, skipping."
  fi

  # ── Oh My Posh (cross-shell prompt used by PowerShell profile)
  if ! command -v oh-my-posh &>/dev/null; then
    log "Installing Oh My Posh..."
    curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
  else
    warn "Oh My Posh already installed, skipping."
  fi

  # ── Lazygit
  if ! command -v lazygit &>/dev/null; then
    log "Installing Lazygit..."
    LAZYGIT_VER=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r '.tag_name' | tr -d 'v')
    curl -Lo /tmp/lazygit.tar.gz \
      "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VER}/lazygit_${LAZYGIT_VER}_Linux_x86_64.tar.gz"
    tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo mv /tmp/lazygit /usr/local/bin/lazygit
    rm /tmp/lazygit.tar.gz
  else
    warn "Lazygit already installed, skipping."
  fi

  # ── Television (fuzzy launcher)
  if ! command -v tv &>/dev/null; then
    log "Installing Television..."
    TV_ASSET=$(curl -s https://api.github.com/repos/alexpasmantier/television/releases/latest |
      jq -r '.assets[] | select(.name | test("x86_64-unknown-linux-musl.*\\.tar\\.gz")) | .browser_download_url' | head -1)
    curl -Lo /tmp/tv.tar.gz "$TV_ASSET"
    mkdir -p /tmp/tv-extract
    tar -xzf /tmp/tv.tar.gz -C /tmp/tv-extract
    sudo find /tmp/tv-extract -name "tv" -type f -exec mv {} /usr/local/bin/tv \;
    rm -rf /tmp/tv.tar.gz /tmp/tv-extract
  else
    warn "Television already installed, skipping."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: kubernetes
# ═════════════════════════════════════════════════════════════════════════════
module_kubernetes() {
  log "━━ Running module: kubernetes ━━"

  if ! command -v kubectl &>/dev/null; then
    log "Installing kubectl..."
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key |
      sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' |
      sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
    apt_update
    apt_install kubectl
  else
    warn "kubectl already installed, skipping."
  fi

  if ! command -v kubectx &>/dev/null; then
    log "Installing kubectx and kubens..."
    sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
    sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
    sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
  else
    warn "kubectx already installed, skipping."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: languages
# ═════════════════════════════════════════════════════════════════════════════
module_languages() {
  log "━━ Running module: languages ━━"

  # ── Go (latest)
  GO_LATEST=$(curl -s "https://go.dev/VERSION?m=text" | head -1 | tr -d '[:space:]')
  INSTALLED_GO=$(go version 2>/dev/null | grep -oP 'go\d+\.\d+\.\d+' | head -1 || echo "none")
  if [ "$INSTALLED_GO" != "$GO_LATEST" ]; then
    log "Installing Go $GO_LATEST..."
    curl -Lo /tmp/go.tar.gz "https://go.dev/dl/${GO_LATEST}.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    export PATH="/usr/local/go/bin:$PATH"
    log "Go $(go version) installed."
  else
    warn "Go $INSTALLED_GO already up to date, skipping."
  fi

  # ── Rust / Cargo
  if [ ! -f "$HOME/.cargo/bin/cargo" ]; then
    log "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    source "$HOME/.cargo/env"
  else
    warn "Rust already installed, skipping."
  fi
  export PATH="$HOME/.cargo/bin:$PATH"

  # ── Just
  if ! command -v just &>/dev/null; then
    log "Installing just..."
    cargo install just
  else
    warn "Just already installed ($(node --version)), skipping."
  fi

  # ── Node.js (LTS via NodeSource)
  if ! command -v node &>/dev/null; then
    log "Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    apt_install nodejs
  else
    warn "Node.js already installed ($(node --version)), skipping."
  fi

  # ── Bun
  if ! command -v bun &>/dev/null; then
    log "Installing bun..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
  else
    warn "bun already installed ($(bun --version)), skipping."
  fi

  # ── PowerShell Core
  if ! command -v pwsh &>/dev/null; then
    log "Installing PowerShell Core..."
    if ! dpkg -l packages-microsoft-prod &>/dev/null 2>&1; then
      curl -fsSL "https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb" \
        -o /tmp/packages-microsoft-prod.deb
      sudo dpkg -i /tmp/packages-microsoft-prod.deb
      rm /tmp/packages-microsoft-prod.deb
      apt_update
    fi
    apt_install powershell
  else
    warn "PowerShell Core already installed, skipping."
  fi

  # ── .NET SDK (LTS)
  if ! command -v dotnet &>/dev/null; then
    log "Installing .NET SDK (LTS)..."
    curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel LTS
    export DOTNET_ROOT="$HOME/.dotnet"
    export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
    log ".NET SDK $(dotnet --version) installed."
  else
    warn ".NET SDK already installed ($(dotnet --version)), skipping."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: dev-tools
# ═════════════════════════════════════════════════════════════════════════════
module_dev_tools() {
  log "━━ Running module: dev-tools ━━"

  # ── gh CLI
  if ! command -v gh &>/dev/null; then
    log "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
      sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
		https://cli.github.com/packages stable main" |
      sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    apt_update
    apt_install gh
  else
    warn "GitHub CLI already installed, skipping."
  fi

  # ── devcontainer CLI
  if ! command -v devcontainer &>/dev/null; then
    log "Installing devcontainer CLI..."
    NPM_PREFIX=$(npm config get prefix 2>/dev/null || echo "")
    if [[ "$NPM_PREFIX" == /usr* ]]; then
      npm config set prefix "$HOME/.local"
    fi
    npm install -g @devcontainers/cli
    export PATH="$HOME/.local/bin:$PATH"
  else
    warn "devcontainer CLI already installed, skipping."
  fi

  # ── Ollama
  if ! command -v ollama &>/dev/null; then
    log "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
  else
    warn "Ollama already installed, skipping."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: claude
# ═════════════════════════════════════════════════════════════════════════════
module_claude() {
  log "━━ Running module: claude ━━"

  log "━━ claude module currently deactivated ━━"
  # if ! command -v claude &>/dev/null; then
  #   log "Installing Claude Code..."
  #   curl -fsSL https://claude.ai/install.sh | bash
  # else
  #   warn "Claude Code already installed, skipping."
  # fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: opencode
# ═════════════════════════════════════════════════════════════════════════════
module_opencode() {
  log "━━ Running module: opencode ━━"

  if ! command -v opencode &>/dev/null; then
    log "Installing opencode..."
    curl -fsSL https://opencode.ai/install | bash
  else
    warn "opencode already installed, skipping."
  fi

  # ── oh-my-opencode (requires bun)
  OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"
  if command -v opencode &>/dev/null && ! grep -q "oh-my-opencode" "$OPENCODE_CONFIG" 2>/dev/null; then
    log "Installing oh-my-opencode..."
    bunx oh-my-opencode install --no-tui --claude=no --openai=no --gemini=no --copilot=no
  else
    warn "oh-my-opencode already installed or opencode not found, skipping."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: pi
# ═════════════════════════════════════════════════════════════════════════════
module_pi() {
  log "━━ Running module: pi ━━"

  # ── npm user prefix (avoid needing root for global installs)
  NPM_PREFIX=$(npm config get prefix 2>/dev/null || echo "")
  if [[ "$NPM_PREFIX" == /usr* ]]; then
    log "Setting npm global prefix to ~/.local..."
    npm config set prefix "$HOME/.local"
  fi

  if ! command -v pi &>/dev/null; then
    log "Installing Pi coding agent..."
    npm install -g @mariozechner/pi-coding-agent
  else
    warn "Pi coding agent already installed, skipping."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MODULE: dotfiles
# ═════════════════════════════════════════════════════════════════════════════
module_dotfiles() {
  log "━━ Running module: dotfiles ━━"

  # ── Locale
  if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
    log "Generating en_US.UTF-8 locale..."
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8
  fi

  # ── Set zsh as default shell
  if [ "$SHELL" != "$(which zsh)" ]; then
    log "Setting zsh as default shell..."
    sudo chsh -s "$(which zsh)" "$USER"
  fi

  # ── Apply dotfiles via stow
  if [ -d "$DOTFILES_DIR" ]; then
    log "Applying dotfiles from $DOTFILES_DIR..."
    mkdir -p "$HOME/.config"
    cd "$DOTFILES_DIR"
    stow .
    cd "$DOTFILES_DIR/dot-pi"
    stow .
    cd "$DOTFILES_DIR/dot-opencode"
    stow .
    log "Dotfiles applied."
  else
    warn "Dotfiles directory $DOTFILES_DIR not found. Clone your dotfiles there and run: cd $DOTFILES_DIR && stow ."
  fi

  # ── Pi agent config (symlinked to ~/.pi — outside ~/.config stow target)
  # mkdir -p "$HOME/.pi/agent"
  # ln -sf "$DOTFILES_DIR/dot-pi/agent/models.json"  "$HOME/.pi/agent/models.json"
  # ln -sf "$DOTFILES_DIR/dot-pi/agent/settings.json" "$HOME/.pi/agent/settings.json"
  # log "Pi agent config symlinked."

  # ── Pull Ollama models defined in Pi agent models.json
  if command -v ollama &>/dev/null && command -v jq &>/dev/null; then
    log "Pulling Ollama models from Pi agent config..."
    jq -r '.providers.ollama.models[].id' "$HOME/.pi/agent/models.json" | while IFS= read -r model; do
      log "  ollama pull $model"
      ollama pull "$model" || warn "Failed to pull model: $model (skipping)"
    done
  else
    warn "ollama or jq not found — skipping model pull. Run manually after install."
  fi

  # ── Ensure ~/.zshrc sources the stowed config
  if [ ! -f "$HOME/.zshrc" ] || ! grep -q "source ~/.config/zshrc/.zshrc" "$HOME/.zshrc" 2>/dev/null; then
    log "Setting up ~/.zshrc wrapper..."
    printf '%s\n' 'source ~/.config/zshrc/.zshrc' >"$HOME/.zshrc"
  fi

  # ── Install Neovim plugins
  # if command -v nvim &>/dev/null && [ -f "$HOME/.config/nvim/init.lua" ]; then
  #   log "Installing Neovim plugins (headless)..."
  #   nvim --headless -c "lua require('lazy').sync({wait=true, show=false})" -c "qa" 2>/dev/null ||
  #     warn "Neovim plugin install failed — open nvim and run :Lazy sync."
  # fi

  # ── PowerShell modules (Terminal-Icons, PSWriteColor)
  if command -v pwsh &>/dev/null; then
    log "Installing PowerShell modules..."
    pwsh -NoProfile -Command "
      \$modules = @('Terminal-Icons', 'PSWriteColor')
      foreach (\$m in \$modules) {
        if (-not (Get-Module -ListAvailable -Name \$m)) {
          Install-Module -Name \$m -Force -Scope CurrentUser -Repository PSGallery
        }
      }
    " || warn "PowerShell module install failed — run manually: Install-Module Terminal-Icons, PSWriteColor"
  fi

  # ── Nerd Font (JetBrains Mono)
  log "Installing JetBrainsMono Nerd Font..."
  FONT_DIR="$HOME/.local/share/fonts"
  mkdir -p "$FONT_DIR"
  curl -Lo /tmp/JetBrainsMono.zip \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  unzip -qo /tmp/JetBrainsMono.zip -d "$FONT_DIR/JetBrainsMono"
  fc-cache -fv "$FONT_DIR" >/dev/null
  rm /tmp/JetBrainsMono.zip
}

# ═════════════════════════════════════════════════════════════════════════════
# Main dispatcher
# ═════════════════════════════════════════════════════════════════════════════

MODULE_ORDER=(system docker podman neovim shell kubernetes languages dev-tools claude opencode pi dotfiles)

for name in "${MODULE_ORDER[@]}"; do
  if [[ ${#ONLY[@]} -gt 0 ]] && ! contains "$name" "${ONLY[@]}"; then continue; fi
  if [[ ${#SKIP[@]} -gt 0 ]] && contains "$name" "${SKIP[@]}"; then continue; fi
  echo ""
  "module_${name//-/_}"
done

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. launch wezterm and enjoy your new terminal setup (select JetBrains Mono Nerd Font if not auto-selected)."
echo "  2. Start tmux and press Ctrl-A + I to install plugins (if not auto-installed)."
echo "  3. Open nvim and run :Lazy sync if plugins weren't installed headlessly."
echo "  6. Load opencode once to download plugins: opencode"
echo "  7. Load pi once to download plugins"
echo "  8. clone  <https://github.com/LDJ-Share/pi-agent-orchestrator-extension> and follow README to set up Pi Agent Orchestrator extension for VS Code"
