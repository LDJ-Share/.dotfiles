# Tech Stack

## Languages
- Bash (shell scripts, setup automation)
- Lua (Neovim configuration, WezTerm configuration)
- Zsh (default shell)
- PowerShell (Windows host scripting)
- Python 3 (build tools, linting)
- Go (runtime)
- Rust/Cargo (runtime)
- Node.js (JavaScript runtime for Pi, OpenCode)
- C# / .NET (SDK installed)

## Runtimes & Platforms
- Ubuntu 24.04 LTS (dev VM)
- Windows 11 Pro/Enterprise (host OS)
- Hyper-V (hypervisor)
- Docker (container runtime)
- Node.js LTS (npm packages)
- Bun (JavaScript/TypeScript runtime)
- Go (latest stable)
- Rust (via rustup)
- .NET SDK (LTS)
- PowerShell Core

## Key Tools & CLI
- **Editors**: Neovim 0.11+, VS Code
- **Git/Version Control**: Git, GitHub CLI (gh), Lazygit
- **Shell Utilities**: Zoxide, Bat, Ripgrep (rg), Fd-find, Fzf, Eza, Tree, Ranger
- **Development**: Just (task runner), Devcontainer CLI, Kubectl, Kubectx, Kubens
- **Productivity**: Television (terminal UI), Oh-My-Posh (shell prompt)
- **Terminal**: Tmux, WezTerm, Zsh + Oh-My-Zsh
- **AI Tools**: Pi coding agent (@mariozechner/pi-coding-agent), OpenCode, Ollama CLI
- **Container**: Docker CE, Docker Compose
- **Code Analysis**: ShellCheck (linting)

## Package Managers
- apt (Ubuntu system packages)
- npm (Node.js packages)
- Cargo (Rust packages)
- pip3 (Python packages)
- GitHub Releases (tool downloads)

## Build & Task Runners
- just (task runner via Cargo)
- Bash scripts (setup.sh, firewall-enable.sh, firewall-disable.sh)
- GitHub Actions (CI/CD for container builds and tests)
- Docker Buildx (multi-stage container builds)

## Container & VM
- Docker (container engine on Ubuntu VM)
- Hyper-V (Windows host hypervisor)
- Hyper-V Internal Switch (OllamaNet - isolated virtual network)
- ghcr.io (GitHub Container Registry - dev-env:latest image)
- Ubuntu:24.04 base image

## AI/LLM Integrations
- **Ollama** (Windows host, GPU-accelerated inference at 10.10.10.10:11434)
- **Pi Coding Agent** (npm package, OpenAI-compatible interface)
- **OpenCode** (npm package, code generation tool)
- **AI Models** (via Ollama):
  - bcluzel/LFM2.5-1.2B-Instruct:Q4_K_M (128k context)
  - lfm2.5-thinking:1.2b (reasoning)
  - phi3:mini (131k context)
  - qwen2.5-coder:0.5b (32k context, code-specific)
  - qwen3.5:0.8b (262k context, multimodal, reasoning)
  - qwen3:1.7b (40k context, reasoning)
  - qwen3:4b (262k context, reasoning - default for Pi)
  - tinyllama:1.1b (2k context, lightweight)
  - deepseek-coder-v2:16b (163k context, code-specific)
  - deepseek-r1:8b (131k context, reasoning)
  - qwen3.5:9b (262k context, multimodal, reasoning)
  - gemma4:26b (262k context, multimodal, reasoning)

## Text Editors & IDE Configuration
- **Neovim Plugins** (lazy.nvim plugin manager):
  - LSP: nvim-lspconfig, mason.nvim, mason-lspconfig, mason-tool-installer
  - Completion: nvim-cmp, cmp-nvim-lsp, cmp-buffer, cmp-path, cmp_luasnip
  - Snippet: LuaSnip, friendly-snippets
  - Formatting: conform.nvim
  - Linting: nvim-lint
  - DAP: nvim-dap, nvim-dap-ui, nvim-dap-virtual-text, mason-nvim-dap
  - Treesitter: nvim-treesitter, nvim-treesitter-textobjects, nvim-ts-autotag
  - UI: bufferline, lualine, dressing, noice, which-key, trouble, telescope
  - Navigation: nvim-tree, telescope-fzf-native, flash, vim-tmux-navigator, vim-maximizer
  - Git: gitsigns, lazygit.nvim
  - Editing: nvim-autopairs, nvim-surround, substitute.nvim, indent-blankline
  - Colorscheme: tokyonight.nvim
  - Session: auto-session
  - Startup: alpha-nvim
  - Dev: lazydev.nvim, nui.nvim, plenary.nvim, nvim-web-devicons

## Firewall & Network Isolation
- **UFW** (Ubuntu host firewall)
- **Windows Firewall** (host-level access control)
- **Hyper-V Network Architecture**: OllamaNet Internal Switch (10.10.10.0/24)
