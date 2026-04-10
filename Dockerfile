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
#
# Build strategy: multi-stage with BuildKit parallelism.
# Independent tool installers run as parallel builder stages; assembler
# collects all outputs; final runs inits in parallel via & + wait.
# ─────────────────────────────────────────────────────────────────────────────

FROM ubuntu:24.04 AS base

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# ─────────────────────────────────────────────────────────────────────────────
# System packages + all apt-based tool repos
# Everything installed as root here so builder stages inherit a clean apt state
# and never need sudo apt-get.
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

# Node.js LTS (required for npm globals in builder stages)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y -qq nodejs \
    && rm -rf /var/lib/apt/lists/*

# eza
RUN mkdir -p /etc/apt/keyrings \
    && wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    > /etc/apt/sources.list.d/gierens.list \
    && chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list \
    && apt-get update -qq && apt-get install -y -qq eza \
    && rm -rf /var/lib/apt/lists/*

# gh CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update -qq && apt-get install -y -qq gh \
    && rm -rf /var/lib/apt/lists/*

# kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
    > /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update -qq && apt-get install -y -qq kubectl \
    && rm -rf /var/lib/apt/lists/*

# PowerShell
RUN curl -fsSL "https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb" \
    -o /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update -qq && apt-get install -y -qq powershell \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupdel ubuntu 2>/dev/null || true \
    && groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/zsh "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${USERNAME}
WORKDIR /home/${USERNAME}

ENV HOME=/home/${USERNAME}
ENV USER=${USERNAME}
ENV LANG=en_US.UTF-8
ENV PATH="/home/dev/.opencode/bin:/home/dev/.local/bin:/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin:/home/dev/.cargo/bin:/home/dev/.dotnet:/home/dev/.dotnet/tools:/home/dev/.bun/bin"

# ─────────────────────────────────────────────────────────────────────────────
# Parallel builder stages — all FROM base, run simultaneously by BuildKit
# ─────────────────────────────────────────────────────────────────────────────

FROM base AS builder-neovim
RUN curl -Lo /tmp/nvim.tar.gz \
    "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" \
    && sudo tar -C /usr/local -xzf /tmp/nvim.tar.gz --strip-components=1 \
    && rm /tmp/nvim.tar.gz

# ──

FROM base AS builder-shell-tools
RUN curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

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

# ──

FROM base AS builder-go
RUN GO_LATEST=$(curl -s "https://go.dev/VERSION?m=text" | head -1 | tr -d '[:space:]') \
    && curl -Lo /tmp/go.tar.gz "https://go.dev/dl/${GO_LATEST}.linux-amd64.tar.gz" \
    && sudo rm -rf /usr/local/go \
    && sudo tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz

# ──

FROM base AS builder-rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

# ──

FROM base AS builder-bun
RUN curl -fsSL https://bun.sh/install | bash

# ──

FROM base AS builder-dotnet
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel LTS

# ──

FROM base AS builder-kubectx
RUN sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx

# ──
# builder-dev-tools: serial after builder-rust (needs cargo + rustup toolchain)

FROM base AS builder-dev-tools
COPY --chown=dev:dev --from=builder-rust /home/dev/.cargo /home/dev/.cargo
COPY --chown=dev:dev --from=builder-rust /home/dev/.rustup /home/dev/.rustup
RUN npm config set prefix "${HOME}/.local" \
    && npm install -g @devcontainers/cli \
    && rm -rf "${HOME}/.npm"
RUN "${HOME}/.cargo/bin/cargo" install just

# ──
# builder-ai-tools: serial after builder-bun (opencode installer detects bun on PATH)

FROM base AS builder-ai-tools
COPY --chown=dev:dev --from=builder-bun /home/dev/.bun /home/dev/.bun
RUN curl -fsSL https://opencode.ai/install | bash
RUN npm config set prefix "${HOME}/.local" \
    && npm install -g @mariozechner/pi-coding-agent \
    && npm install -g @cmcconomy/pi-qwen-tool-parser@1.0.0 \
    && rm -rf "${HOME}/.npm"

# Verify installation
RUN pi --version

# ─────────────────────────────────────────────────────────────────────────────
# assembler — collects all builder outputs, then stows dotfiles
# ─────────────────────────────────────────────────────────────────────────────

FROM base AS assembler

# ── Neovim
COPY --from=builder-neovim /usr/local/bin/nvim /usr/local/bin/nvim
COPY --from=builder-neovim /usr/local/lib/nvim /usr/local/lib/nvim
COPY --from=builder-neovim /usr/local/share/nvim /usr/local/share/nvim

# ── Shell tools
COPY --chown=dev:dev --from=builder-shell-tools /home/dev/.local/bin/zoxide /home/dev/.local/bin/zoxide
COPY --chown=dev:dev --from=builder-shell-tools /home/dev/.local/bin/oh-my-posh /home/dev/.local/bin/oh-my-posh
COPY --from=builder-shell-tools /usr/local/bin/lazygit /usr/local/bin/lazygit
COPY --from=builder-shell-tools /usr/local/bin/tv /usr/local/bin/tv
COPY --from=builder-shell-tools /usr/local/bin/fzf /usr/local/bin/fzf

# ── Go
COPY --from=builder-go /usr/local/go /usr/local/go

# ── Rust (full dirs first, then just from dev-tools on top)
COPY --chown=dev:dev --from=builder-rust /home/dev/.cargo /home/dev/.cargo
COPY --chown=dev:dev --from=builder-rust /home/dev/.rustup /home/dev/.rustup

# ── Bun
COPY --chown=dev:dev --from=builder-bun /home/dev/.bun /home/dev/.bun

# ── .NET
COPY --chown=dev:dev --from=builder-dotnet /home/dev/.dotnet /home/dev/.dotnet

# ── kubectx (symlinks require a RUN since /usr/local/bin is a system path)
COPY --from=builder-kubectx /opt/kubectx /opt/kubectx
RUN sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx \
    && sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens

# Set npm prefix so `npm config get prefix` resolves to ~/.local at runtime.
# This ensures test_pi.sh finds packages under ~/.local/lib/node_modules/.
RUN npm config set prefix "${HOME}/.local"

# ── Dev tools (scoped copies to avoid clobbering rust binaries already present)
COPY --chown=dev:dev --from=builder-dev-tools /home/dev/.cargo/bin/just /home/dev/.cargo/bin/just
COPY --chown=dev:dev --from=builder-dev-tools /home/dev/.local/bin/devcontainer /home/dev/.local/bin/devcontainer
COPY --chown=dev:dev --from=builder-dev-tools /home/dev/.local/lib/node_modules/@devcontainers /home/dev/.local/lib/node_modules/@devcontainers

# ── AI tools (scoped copies to avoid clobbering node_modules from dev-tools)
COPY --chown=dev:dev --from=builder-ai-tools /home/dev/.opencode /home/dev/.opencode
COPY --chown=dev:dev --from=builder-ai-tools /home/dev/.local/bin/pi /home/dev/.local/bin/pi
COPY --chown=dev:dev --from=builder-ai-tools /home/dev/.local/lib/node_modules/@mariozechner /home/dev/.local/lib/node_modules/@mariozechner
COPY --chown=dev:dev --from=builder-ai-tools /home/dev/.local/lib/node_modules/@cmcconomy /home/dev/.local/lib/node_modules/@cmcconomy

# ── Dotfiles and stow
# Placed late so config changes don't bust the tool-install cache above.
COPY --chown=dev:dev . /home/dev/.dotfiles/

# Stow root dotfiles → ~/.config  (nvim, tmux, zshrc, ssh, television, etc.)
RUN mkdir -p "${HOME}/.config" \
    && cd "${HOME}/.dotfiles" \
    && stow .

# Stow dot-pi → ~/.pi/agent  (models.json, settings.json)
RUN mkdir -p "${HOME}/.pi/agent" \
    && cd "${HOME}/.dotfiles/dot-pi" \
    && stow .

# Stow dot-opencode → ~/.opencode  (config.json, oh-my-opencode.json)
# opencode binary is already at ~/.opencode/bin/opencode (from builder-ai-tools);
# stow safely adds the config symlinks alongside it.
RUN mkdir -p "${HOME}/.opencode" \
    && cd "${HOME}/.dotfiles/dot-opencode" \
    && stow .

# Write ~/.zshrc wrapper (sources the stowed zshrc)
RUN printf '%s\n' 'source ~/.config/zshrc/.zshrc' > "${HOME}/.zshrc"

# ─────────────────────────────────────────────────────────────────────────────
# final — pre-initialization (parallel via & + wait)
#
# All applications are fully initialized here so nothing is lazy-loaded at
# runtime on the corporate machine (no internet required after docker pull).
#
# tmux TPM install and oh-my-opencode install run in background while the
# three sequential nvim init commands run in the foreground group.
# Wall-clock time: max(~10 min nvim, ~1.5 min tmux, ~1.5 min opencode) ≈ 10 min.
#
# Note: oh-my-opencode writes to ~/.config/opencode/opencode.json (XDG path),
# not through the ~/.opencode/config.json stow symlink.
# ─────────────────────────────────────────────────────────────────────────────

FROM assembler AS final

RUN git clone https://github.com/tmux-plugins/tpm "${HOME}/.tmux/plugins/tpm"
RUN TMUX_PLUGIN_MANAGER_PATH="${HOME}/.tmux/plugins" "${HOME}/.tmux/plugins/tpm/scripts/install_plugins.sh" 2>/dev/null || true
RUN "${HOME}/.bun/bin/bunx" oh-my-opencode install --no-tui --claude=no --openai=no --gemini=no --copilot=no 2>/dev/null || true
RUN npx get-shit-done-cc --opencode --global 
RUN nvim --headless "+Lazy! sync" +qa  2>/dev/null || true
RUN nvim --headless "+MasonInstall typescript-language-server" +qa
RUN nvim --headless "+MasonInstall html-lsp" +qa
RUN nvim --headless "+MasonInstall css-lsp" +qa
RUN nvim --headless "+MasonInstall tailwindcss-language-server" +qa
RUN nvim --headless "+MasonInstall svelte-language-server" +qa
RUN nvim --headless "+MasonInstall lua-language-server" +qa
RUN nvim --headless "+MasonInstall emmet-ls" +qa
RUN nvim --headless "+MasonInstall prisma-language-server" +qa
RUN nvim --headless "+MasonInstall pyright" +qa
RUN nvim --headless "+MasonInstall eslint-lsp" +qa
RUN nvim --headless "+MasonInstall gopls" +qa
RUN nvim --headless "+MasonInstall bash-language-server" +qa
RUN nvim --headless "+MasonInstall json-lsp" +qa
RUN nvim --headless "+MasonInstall omnisharp" +qa
RUN nvim --headless "+MasonToolsInstallSync" +qa

# ─────────────────────────────────────────────────────────────────────────────
WORKDIR /workspace
CMD ["/bin/zsh"]
