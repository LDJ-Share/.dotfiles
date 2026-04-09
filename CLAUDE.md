<!-- GSD:project-start source:PROJECT.md -->
## Project

**Air-Gapped AI Dev Environment — Compose-First Deployment**

A hardened, all-in-one AI coding environment deployable as a docker-compose stack into air-gapped machines. The stack pairs an existing dev container (Neovim, Pi, OpenCode, full toolchain) with a co-deployed Ollama container on an internal Docker network — no firewall holes, no external internet after initial pull. Supports VS Code devcontainer workflow, Podman, and CPU/GPU machines.

**Core Value:** A developer on an air-gapped machine can open VS Code, reopen in devcontainer, and immediately have a full AI coding session — with no setup, no internet, and no firewall exceptions.

### Constraints

- **Air-gap**: All dependencies must be baked in at build time — no runtime internet access after export
- **Portability**: Must work on machines with no Docker Desktop, no GUI docker tooling
- **Compatibility**: Compose file must run under both `docker compose` v2 and `podman compose`
- **GPU**: Optional NVIDIA passthrough — must degrade gracefully to CPU
- **Models**: gemma4:26b (~17GB) + gemma4:e4b (~5GB) → ~22GB minimum disk on air-gapped machine
- **Registry**: Images published to GHCR alongside existing dev-env image
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

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
## Text Editors & IDE Configuration
- **Neovim Plugins** (lazy.nvim plugin manager):
## Firewall & Network Isolation
- **UFW** (Ubuntu host firewall)
- **Windows Firewall** (host-level access control)
- **Hyper-V Network Architecture**: OllamaNet Internal Switch (10.10.10.0/24)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Conventions
### Directory Structure
- **Dotfile packages** use `dot-<name>` prefix for stow directories (e.g., `dot-pi`, `dot-opencode`)
- **Module directories** follow function domain: `nvim/`, `tmux/`, `zshrc/`, `powershell/`, `ssh/`, `wezterm/`, `television/`, etc.
- **Configuration target** specified in `.stowrc`: all packages stow to `~/.config` via `--target=~/.config`
- **.stowrc ignore patterns**: Each `dot-*` directory may include its own `.stowrc` with `--ignore` directives to skip non-config files
### File Naming
- **Shell scripts** are executable and named with `.sh` extension
- **Test scripts** follow pattern `test_<component>.sh` (e.g., `test_neovim.sh`, `test_pi.sh`)
- **Helper scripts** live in shared locations: `tests/container/helpers.sh`
- **Configuration files** use standard formats: `.json`, `.conf`, `.lua`, `.toml`
- **Lock files** track plugin versions: `lazy-lock.json` (Neovim), no explicit npm/yarn locks in dotfiles
### Stow Package Organization
- Source files are organized by target path under `~/.config`
- Example: `nvim/init.lua` stows to `~/.config/nvim/init.lua`
- Ignored files (scripts, docs, lock files) are listed in respective `.stowrc` files
- Each stow target is **modular and independent**
## Shell Script Style
### Shebang and Preamble
- `e`: exit on error
- `u`: error on undefined variables
- `o pipefail`: error if any command in a pipeline fails
### Utility Functions
- `GREEN='\033[0;32m'` for success messages
- `YELLOW='\033[1;33m'` for warnings
- `RED='\033[0;31m'` for errors
- Helper functions: `log()`, `warn()`, `err()` (error to stderr with `>&2`)
- `check()` — verify condition, increment PASS/FAIL
- `check_cmd()` — verify command on PATH
- `check_file()` — verify file exists
- `check_dir()` — verify directory exists
- `check_contains()` — verify file contains pattern
- `check_not_contains()` — verify file does NOT contain pattern
- `summary()` — print results and exit with code
### Error Handling Patterns
- Precondition checks early (root user, variable existence)
- Exit code 0 for success, 1 for failure
- Redirect stderr to /dev/null when not needed: `command &>/dev/null`
- Suppress apt output with `-y -qq` and dpkg options
- Use `|| true` to allow non-critical commands to fail without exiting
### Documentation Comments
- Full-width separator lines for major sections using `═` characters
- Dashed separators `─` for subsections
- Script headers document PURPOSE, WHAT IT DOES, USAGE, WHEN TO RUN, REQUIREMENTS
- Inline comments explain non-obvious logic
### Conditionals
- Prefer `if [[ ... ]]; then` (bash) over POSIX `[ ... ]`
- Test command existence: `command -v <name> &>/dev/null`
- Test apt package: `dpkg -l <package-name> &>/dev/null 2>&1`
## Configuration Style
### JSON Configuration Files
- **Indentation**: 2 spaces
- **URL consistency**: All Ollama URLs use `10.10.10.10:11434` (OllamaNet host), never `127.0.0.1` or `localhost`
- **Models enumerated** in provider-specific arrays with `id`, `contextWindow`, `input`, optional `reasoning` flags
- **Provider format**: Pi uses `openai-completions` API; OpenCode uses `@ai-sdk/openai-compatible`
### Pi Configuration (dot-pi/)
- `models.json`: Lists available models under `providers.ollama.models[]`
- `settings.json`: `defaultModel`, `defaultProvider`, `packages` array for npm pre-installs
### OpenCode Configuration (dot-opencode/)
- `config.json`: Model, provider config, all available models listed
- `oh-my-opencode.json`: 10 pre-configured agents and 6 categories
- Optional variants: `oh-my-opencode-qwen3.4b.json` for specific models
### Neovim Configuration (LazyVim)
- LazyVim starter from josean-dev/dev-environment-files
- Plugin manager: `lazy.nvim` with `lazy-lock.json`
- Mason tools: Explicit LSP servers and formatters in config
- Formatting: `stylua.toml` for Lua code style
### tmux Configuration
- File: `tmux/tmux.conf` with TPM plugins
- All plugins cloned at container build time
- Reset fallback: `tmux.reset.conf`
### Shell Configuration (zsh)
- Default shell in container
- Oh My Posh theme integration
- Stows to `~/.config/zsh/`
## Commit Style
### Conventional Commits Format
- `feat:` — new feature/capability
- `fix:` — bug fix
- `perf:` — performance improvement
- `refactor:` — reorganization without functional change
- `chore:` — maintenance, dependencies, non-functional
- `docs:` — documentation only
- `ci:` — CI/CD pipeline
- `fix: set npm prefix in assembler so test_pi.sh resolves correct path`
- `perf: refactor Dockerfile to parallel multi-stage build`
- `feat: add gemma4:26b to Pi models and set as default`
### Branching Model
- **master**: production-ready, tested
- **feature/<name>**: feature branches (e.g., `feature/phase5-readme`)
- **CI trigger**: Pushes to master that touch Dockerfile, dotfiles, or tests trigger full pipeline
## Documentation Style
### README Structure
- Table of Contents for navigation
- Business context section (for leaders)
- Architecture overview with ASCII diagrams
- Technical setup instructions
- Comparison tables for decisions
### Plan Documents
- Location: `docs/superpowers/plans/` and `docs/superpowers/specs/`
- Naming: `YYYY-MM-DD-<description>.md`
- Format: Markdown with sections and code blocks
### Code Documentation
- Module headers: PURPOSE, WHAT IT DOES, USAGE details
- Section separators: Full-width and dashed lines
- Test comments: Explain what each check verifies
## Stow Conventions
### Package Structure
- Source layout mirrors target layout under `~/.config`
- Each package has optional `.stowrc` to exclude non-config files
- `.stowrc` entries: `--target=~/.config`, `--ignore` patterns for scripts/docs/locks
### Apply Strategy
- Command: `stow .` from dotfiles root
- Module: `setup.sh --only dotfiles` applies stow and sets zsh default
- Idempotent: Safe to run multiple times
- Stow warns on conflicts (manual resolution needed)
### What Gets Stowed
- Configuration: `.lua`, `.conf`, `.toml`, JSON configs
- Shell: `.zshrc`, Oh My Posh themes
- Editor: Neovim init, Mason configs
### What Doesn't Get Stowed
- Scripts: Listed in `.stowrc` ignore
- Lock files: `lazy-lock.json`, Mason registries
- Build artifacts: `luac/`, `spell/`, `tmp/`, `plugins/`, `mason/`
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## System Overview
## Summary
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
