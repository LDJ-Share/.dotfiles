# Conventions

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
Uses `#!/usr/bin/env bash` with `set -euo pipefail` for cross-platform compatibility and strict error handling:
- `e`: exit on error
- `u`: error on undefined variables
- `o pipefail`: error if any command in a pipeline fails

### Utility Functions
**Color output** is standard across all scripts:
- `GREEN='\033[0;32m'` for success messages
- `YELLOW='\033[1;33m'` for warnings
- `RED='\033[0;31m'` for errors
- Helper functions: `log()`, `warn()`, `err()` (error to stderr with `>&2`)

**Test utility functions** in `tests/container/helpers.sh`:
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
Type prefix (lowercase) + brief description:
- `feat:` — new feature/capability
- `fix:` — bug fix
- `perf:` — performance improvement
- `refactor:` — reorganization without functional change
- `chore:` — maintenance, dependencies, non-functional
- `docs:` — documentation only
- `ci:` — CI/CD pipeline

**Examples:**
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
