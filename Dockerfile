# ─────────────────────────────────────────────────────────────────────────────
# Air-gapped AI Dev Environment — Container Image
#
# Published to: ghcr.io/ldj-share/.dotfiles/dev-env:latest
#
# Usage (on the corporate VM, after docker pull):
#   docker run -it --rm -v ~/workspace:/workspace dev-env:latest
#
# Ollama runs on the Windows HOST at 10.10.10.10:11434 over the OllamaNet
# Hyper-V Internal Switch. The container inherits the VM's network namespace,
# so all Ollama URLs already point at the right address.
#
# What is NOT in this image (lives on the VM host layer):
#   - Docker Engine (needed to run this image)
#   - Ollama (runs on Windows host with GPU access)
#   - Hyper-V / firewall scripts (VM OS-level)
# ─────────────────────────────────────────────────────────────────────────────

FROM ubuntu:24.04

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 1 — System packages
# Grouped together to minimise layer count for rarely-changing base deps.
# ─────────────────────────────────────────────────────────────────────────────
RUN apt-get update -qq && apt-get install -y -qq \
    apt-transport-https \
    bat \
    build-essential \
    ca-certificates \
    curl \
    direnv \
    fd-find \
    ffmpeg \
    fzf \
    git \
    gitk \
    gnupg \
    jq \
    locales \
    lsb-release \
    nmap \
    python3 \
    python3-pip \
    ranger \
    ripgrep \
    software-properties-common \
    stow \
    sudo \
    tar \
    tmux \
    tree \
    unzip \
    wget \
    zip \
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    && pip3 install --break-system-packages pylint isort black \
    && ln -sf "$(which fdfind)" /usr/local/bin/fd \
    && ln -sf "$(which batcat)" /usr/local/bin/bat \
    && locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 2 — Non-root user
# ─────────────────────────────────────────────────────────────────────────────
RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/zsh "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${USERNAME}
WORKDIR /home/${USERNAME}

ENV HOME=/home/${USERNAME}
ENV USER=${USERNAME}
ENV LANG=en_US.UTF-8

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 3 — Neovim (AppImage, >= 0.11 required for fzf-lua)
# ─────────────────────────────────────────────────────────────────────────────
RUN curl -Lo /tmp/nvim.appimage \
    "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage" \
    && chmod +x /tmp/nvim.appimage \
    && sudo mv /tmp/nvim.appimage /usr/local/bin/nvim

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 4 — Shell tools
# zoxide, eza, lazygit, television, oh-my-posh, upgraded fzf
# ─────────────────────────────────────────────────────────────────────────────
RUN curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

RUN sudo mkdir -p /etc/apt/keyrings \
    && wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
       | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
       | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null \
    && sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list \
    && sudo apt-get update -qq && sudo apt-get install -y -qq eza \
    && sudo rm -rf /var/lib/apt/lists/*

RUN LAZYGIT_VER=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
      | jq -r '.tag_name' | tr -d 'v') \
    && curl -Lo /tmp/lazygit.tar.gz \
       "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VER}/lazygit_${LAZYGIT_VER}_Linux_x86_64.tar.gz" \
    && tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit \
    && sudo mv /tmp/lazygit /usr/local/bin/lazygit \
    && rm /tmp/lazygit.tar.gz

RUN TV_ASSET=$(curl -s https://api.github.com/repos/alexpasmantier/television/releases/latest \
      | jq -r '.assets[] | select(.name | test("x86_64-unknown-linux-musl.*\\.tar\\.gz")) | .browser_download_url' | head -1) \
    && curl -Lo /tmp/tv.tar.gz "${TV_ASSET}" \
    && mkdir -p /tmp/tv-extract \
    && tar -xzf /tmp/tv.tar.gz -C /tmp/tv-extract \
    && sudo find /tmp/tv-extract -name "tv" -type f -exec mv {} /usr/local/bin/tv \; \
    && rm -rf /tmp/tv.tar.gz /tmp/tv-extract

RUN curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "${HOME}/.local/bin"

# Upgrade fzf (apt version too old for fzf-lua >= 0.53)
RUN FZF_ASSET=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest \
      | jq -r '.assets[] | select(.name | test("linux_amd64\\.tar\\.gz")) | .browser_download_url' | head -1) \
    && curl -sSfL "${FZF_ASSET}" | tar -xz -C /tmp \
    && sudo mv /tmp/fzf /usr/local/bin/fzf

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 5 — Language runtimes
# Go, Rust, Node.js (LTS), Bun, PowerShell, .NET SDK
# ─────────────────────────────────────────────────────────────────────────────
RUN GO_LATEST=$(curl -s "https://go.dev/VERSION?m=text" | head -1 | tr -d '[:space:]') \
    && curl -Lo /tmp/go.tar.gz "https://go.dev/dl/${GO_LATEST}.linux-amd64.tar.gz" \
    && sudo rm -rf /usr/local/go \
    && sudo tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - \
    && sudo apt-get install -y -qq nodejs \
    && sudo rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://bun.sh/install | bash

RUN if ! dpkg -l packages-microsoft-prod >/dev/null 2>&1; then \
      curl -fsSL "https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb" \
        -o /tmp/packages-microsoft-prod.deb \
      && sudo dpkg -i /tmp/packages-microsoft-prod.deb \
      && rm /tmp/packages-microsoft-prod.deb; \
    fi \
    && sudo apt-get update -qq \
    && sudo apt-get install -y -qq powershell \
    && sudo rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel LTS

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 6 — Dev tools
# gh CLI, kubectl, kubectx/kubens, devcontainer CLI, just
# ─────────────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
    && sudo apt-get update -qq && sudo apt-get install -y -qq gh \
    && sudo rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
      | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
      | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null \
    && sudo apt-get update -qq && sudo apt-get install -y -qq kubectl \
    && sudo rm -rf /var/lib/apt/lists/*

RUN sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx \
    && sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx \
    && sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens

# devcontainer CLI + just (cargo)
# Set npm prefix before any global installs
RUN npm config set prefix "${HOME}/.local" \
    && npm install -g @devcontainers/cli

RUN "${HOME}/.cargo/bin/cargo" install just

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 7 — AI tools: OpenCode, oh-my-opencode, Pi
# ─────────────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://opencode.ai/install | bash

# Install Pi coding agent
RUN npm install -g @mariozechner/pi-coding-agent

# Pre-install Pi extension packages from settings.json (prevents runtime download)
RUN npm install -g @cmcconomy/pi-qwen-tool-parser@1.0.0

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 8 — Copy dotfiles and stow
# Placed late so config changes don't bust the tool-install cache above.
# ─────────────────────────────────────────────────────────────────────────────
COPY --chown=${USERNAME}:${USERNAME} . /home/${USERNAME}/.dotfiles/

# Stow root dotfiles → ~/.config  (nvim, tmux, zshrc, ssh, television, etc.)
RUN mkdir -p "${HOME}/.config" \
    && cd "${HOME}/.dotfiles" \
    && stow .

# Stow dot-pi → ~/.pi/agent  (models.json, settings.json)
RUN mkdir -p "${HOME}/.pi/agent" \
    && cd "${HOME}/.dotfiles/dot-pi" \
    && stow .

# Stow dot-opencode → ~/.opencode  (config.json, oh-my-opencode.json)
RUN mkdir -p "${HOME}/.opencode" \
    && cd "${HOME}/.dotfiles/dot-opencode" \
    && stow .

# Write ~/.zshrc wrapper (sources the stowed zshrc)
RUN printf '%s\n' 'source ~/.config/zshrc/.zshrc' > "${HOME}/.zshrc"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 9 — Pre-initialization
# All applications are fully initialized here so nothing is lazy-loaded at
# runtime on the corporate machine (no internet required after docker pull).
# ─────────────────────────────────────────────────────────────────────────────

# ── PATH for all pre-init commands
ENV PATH="${HOME}/.local/bin:/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin:${HOME}/.cargo/bin:${HOME}/.dotnet:${HOME}/.dotnet/tools:${HOME}/.bun/bin:${PATH}"

# ── Neovim: bootstrap lazy.nvim and sync all plugins
RUN nvim --headless \
    -c "lua require('lazy').sync({wait=true, show=false})" \
    -c "qa" 2>/dev/null || true

# ── Neovim: install Mason LSP servers (mason-lspconfig ensure_installed)
# Triggered by loading the full config; defer exit to allow Mason to complete.
RUN nvim --headless \
    -c "lua vim.defer_fn(function() vim.cmd('qa') end, 180000)" \
    2>/dev/null || true

# ── Neovim: install Mason tools (mason-tool-installer, run_on_start=false by default)
RUN nvim --headless \
    -c "MasonToolsInstall" \
    -c "lua vim.defer_fn(function() vim.cmd('qa') end, 180000)" \
    2>/dev/null || true

# ── tmux: clone TPM and install all plugins from tmux.conf headlessly
RUN git clone https://github.com/tmux-plugins/tpm "${HOME}/.tmux/plugins/tpm" \
    && TMUX_PLUGIN_MANAGER_PATH="${HOME}/.tmux/plugins" \
       "${HOME}/.tmux/plugins/tpm/scripts/install_plugins.sh" 2>/dev/null || true

# ── oh-my-opencode: install agents and modify opencode config
RUN "${HOME}/.bun/bin/bunx" oh-my-opencode install \
    --no-tui --claude=no --openai=no --gemini=no --copilot=no 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────────
WORKDIR /workspace
CMD ["/bin/zsh"]
