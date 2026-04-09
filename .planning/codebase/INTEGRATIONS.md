# Integrations

## External Services

### GitHub / GHCR
- **Build & Publish**: GitHub Actions builds Docker images on every master push
- **Registry**: ghcr.io/ldj-share/.dotfiles/dev-env:latest (pre-built container)
- **Authentication**: GITHUB_TOKEN for GHCR publish
- **Workflow Triggers**: Dockerfile, setup.sh, dot-pi, dot-opencode, nvim, tmux, zshrc changes

### Ollama (Local AI Inference)
- **Host**: Windows 10/11 Pro/Enterprise with NVIDIA RTX GPU
- **Service Address**: 10.10.10.10:11434 (OllamaNet Hyper-V Internal Switch only)
- **Usage**: Pi coding agent, OpenCode, and any custom scripts query Ollama over HTTP
- **Models**: Pre-pulled on Windows host before VM air-gap deployment
- **Environment Variable**: OLLAMA_HOST=10.10.10.10:11434

### SSH / Remote Access
- **Port**: 22/tcp on OllamaNet (10.10.10.10 → VM only)
- **Usage**: Remote-SSH from VS Code, devcontainer connections
- **Authentication**: SSH key-based (host user → dev account in VM)
- **Server**: OpenSSH enabled and auto-started in VM

## Internal Integrations

### Container Build Chain
1. **Dockerfile** (multi-stage BuildKit):
   - **builder-neovim**: Downloads latest Neovim tarball → /usr/local/bin
   - **builder-shell-tools**: Installs zoxide, lazygit, television, oh-my-posh, fzf via GitHub releases
   - **builder-go**: Installs latest Go from go.dev
   - **builder-rust**: Installs Rust via rustup
   - **builder-bun**: Installs Bun JavaScript runtime
   - **builder-dotnet**: Installs .NET SDK LTS
   - **builder-kubectx**: Git clones kubectx to /opt
   - **builder-dev-tools**: Installs devcontainer CLI and just via cargo
   - **builder-ai-tools**: Installs opencode and Pi npm packages via Bun
   - **assembler**: Collects all builder outputs, applies stow for dotfiles symlinks
   - **final**: Pre-initializes all tools (Neovim lazy sync, Mason LSPs, Tmux TPM, OpenCode)

### Dotfiles Management (GNU Stow)
- **.stowrc** target directory: `~/.config`
- **Root dotfiles** → `~/.config/` (nvim, tmux, zshrc, ssh, television, wezterm)
- **dot-pi/** → `~/.pi/agent/` via stow (models.json, settings.json)
- **dot-opencode/** → `~/.opencode/` via stow (config.json)
- **Ignored**: setup.sh, firewall-*.sh, justfile, README.md, dot-claude, powershell

### Pi Coding Agent Setup
- **npm package**: @mariozechner/pi-coding-agent
- **Configuration**: dot-pi/models.json (Ollama provider) + dot-pi/settings.json
- **Default Model**: gemma4:26b (262k context, multimodal, reasoning enabled)
- **Default Thinking Level**: medium
- **Packages**: @cmcconomy/pi-qwen-tool-parser@1.0.0

### OpenCode AI Tool Setup
- **npm package**: Installed via https://opencode.ai/install
- **Configuration**: dot-opencode/config.json
- **Provider**: Ollama (@ai-sdk/openai-compatible)
- **Base URL**: http://10.10.10.10:11434/v1
- **Default Model**: ollama/qwen3:4b
- **Initialization**: oh-my-opencode install (runs in Dockerfile final stage)

### Neovim LSP & Debugging
- **Plugin Manager**: lazy.nvim (auto-installs plugins from lazy-lock.json)
- **LSP Server Manager**: Mason (auto-installs language servers)
- **Installed LSPs** (pre-initialized in Dockerfile):
  - typescript-language-server, html-lsp, css-lsp, tailwindcss-language-server
  - svelte-language-server, lua-language-server, graphql-language-service-cli
  - emmet-ls, prisma-language-server, pyright, eslint-lsp, gopls
  - bash-language-server, json-lsp, omnisharp
- **DAP (Debugging)**: nvim-dap + mason-nvim-dap

### Shell Configuration
- **Login Shell**: zsh (set by setup.sh)
- **Config Files**: zshrc/.zshrc, zshrc/.p10k.zsh (Powerlevel10k prompt)
- **Autocompletion**: kubectl completion, AWS CLI completion, bashcompinit
- **Bindings**: Custom keybinds for autosuggest, vi-mode navigation
- **Aliases**: Git (gc, gp, gst, glog, gdiff), Docker (dco, dps, dpa), Navigation
- **PATH Extension**: ~/.local/bin, ~/.cargo/bin, ~/.dotnet, ~/.dotnet/tools, /usr/local/go/bin

### Tmux Configuration
- **Plugin Manager**: TPM (Tmux Plugin Manager)
- **Pre-initialized**: Plugins installed in Dockerfile final stage
- **Config**: tmux/tmux.conf (stowed to ~/.config/tmux/)

### WezTerm Terminal
- **Configuration**: wezterm/wezterm.lua (Lua-based config)
- **Integration**: Cross-platform terminal (Windows/Linux/macOS)

### Television (Terminal Navigator)
- **CLI Tool**: Installed from GitHub releases
- **Configuration**: television/cable/*.toml (extensible cable definitions)
- **Cables**: AWS buckets, Docker containers, cargo commands, git history, cron, dirs, etc.

### VS Code Integration
- **Devcontainer**: Defined in .devcontainer/devcontainer.json
- **Image**: ghcr.io/ldj-share/.dotfiles/dev-env:latest
- **Workspace Mount**: /workspace (bind mount from host)
- **Extensions**: Listed in vsc-extensions.txt, pre-installed in Dockerfile

### PowerShell Configuration
- **Host OS Tool**: Windows host setup and Ollama control
- **Profiles**: Microsoft.PowerShell_profile.ps1, Microsoft.PowerShell_profile-PSReadLine.ps1
- **Theme**: oh-my-posh-tokyo-night-storm.toml
- **Documentation**: Windows-PowerShell-Cli-Tool-Installation-Guide.md

### Test Suite
- **Container Tests** (tests/container/):
  - test_binaries.sh: Verifies all CLI tools are on PATH (30+ tools)
  - test_neovim.sh: Checks nvim version, plugins, LSP servers, DAP
  - test_tmux.sh: Confirms tmux and plugins
  - test_opencode.sh: Validates opencode CLI and config
  - test_pi.sh: Checks Pi agent, npm packages, Ollama connectivity
  - test_configs.sh: Stow symlinks, file permissions, dotfiles integrity
- **Firewall Tests** (.github/workflows/test-firewall.yml):
  - UFW enable/disable: Hardening, sudo removal, sudoers validation
  - Integration tests in privileged container (network namespace isolation)
  - ShellCheck linting

## Configuration Dependencies

### Ollama Connection
- **Required Environment**: OLLAMA_HOST=10.10.10.10:11434 (set in Dockerfile PATH, used by Pi/OpenCode)
- **API Endpoint**: http://10.10.10.10:11434/v1 (OpenAI-compatible)
- **Authentication**: None (local network, hardened firewall)
- **Dependency Chain**: Dockerfile → dot-pi/models.json → Pi settings → Ollama HTTP calls

### Container Image
- **Base**: ubuntu:24.04
- **Registry**: ghcr.io (fetch requires Docker Engine on VM)
- **Credentials**: GHCR pull requires no auth for public images
- **Cache**: GitHub Actions cache-from type=gha (faster rebuilds)

### SSH Key Configuration
- **Location**: ssh/ directory (stowed to ~/.ssh/)
- **Default Identity**: Used by Remote-SSH from Windows host
- **Port**: 22/tcp (UFW allow rule from 10.10.10.10)

### NPM & Node Configuration
- **npm prefix**: ~/.local (set in Dockerfile, verified by tests)
- **Node Modules Paths**:
  - ~/.local/lib/node_modules/@mariozechner/ (Pi agent)
  - ~/.local/lib/node_modules/@cmcconomy/ (Pi Qwen tool parser)
  - ~/.local/lib/node_modules/@devcontainers/ (devcontainer CLI)
- **Global Bins**: ~/.local/bin (pi, opencode, devcontainer commands)

### Python & Pip
- **System Packages**: pylint, isort, black (installed in Dockerfile base)
- **Location**: /usr/lib/python3/dist-packages (system-wide)

### Kubernetes
- **Config**: KUBECONFIG=~/.kube/config (exported in .zshrc)
- **Tools**: kubectl (v1.30), kubectx, kubens
- **Completion**: kubectl zsh completion sourced in .zshrc

## Network Dependencies

### Air-Gapped Deployment Network Restrictions
- **VM Inbound**:
  - SSH (port 22/tcp) from 10.10.10.10 only (Windows host)
  - Loopback (localhost) unrestricted
  - All other inbound: DENIED (UFW default-deny-incoming)

- **VM Outbound**:
  - TCP to 10.10.10.10:11434 (Ollama) - **ONLY permitted outbound**
  - Loopback (localhost) unrestricted
  - All other outbound: DENIED (UFW default-deny-outgoing)

- **No Access To**:
  - Physical LAN
  - Wi-Fi
  - Public internet
  - Other VMs
  - Other machines on network

### Windows Host Network
- **OllamaNet Switch Type**: Hyper-V Internal Switch (isolated, no physical NIC)
- **OllamaNet CIDR**: 10.10.10.0/24 (host: 10.10.10.10, VM: 10.10.10.20)
- **Windows Firewall**: Inbound rule scoped to LocalAddress 10.10.10.10, LocalPort 11434
- **No External Connectivity**: OllamaNet cannot reach physical adapters by hypervisor design

### Corporate Network Integration
- **Build Environment**: GitHub Actions (github.com, public internet)
- **Whitelisting**: Corporate machine only needs ghcr.io:443 (container pull)
- **No Direct Package Manager Access**: apt, npm, cargo, crates.io, github.com releases NOT contacted from corporate network
- **Pre-built Images**: All dependencies baked into ghcr.io image during public build

### Credential & Secret Management
- **GITHUB_TOKEN**: Used by GitHub Actions to push to GHCR (secrets context)
- **No External APIs**: Pi and OpenCode do not contact OpenAI, Claude, Gemini APIs (Ollama only)
- **SSH Keys**: Local filesystem only (no GitHub/GitLab auth required)

### Firewall Governance
- **UFW Rules**:
  - Inbound: loopback + SSH from 10.10.10.10 only
  - Outbound: loopback + 10.10.10.10:11434 only
  - Default: DENY INCOMING, DENY OUTGOING
- **Immutability**: Dev account has no sudo → cannot modify UFW rules
- **Kernel Enforcement**: UFW rules enforced by iptables/nftables (kernel-level, bypass-proof)

### Model Governance
- **Model List**: dot-pi/models.json (enumerated at build time)
- **Pre-pulled**: All models pulled on Windows host before VM export
- **No Dynamic Fetching**: VM has no internet → cannot pull new models
- **Addition Process**: Add to models.json, re-stow config, restart Pi (no external fetch)
