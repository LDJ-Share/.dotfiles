# Testing

## Test Framework

### Container Tests (Primary Test Suite)
- **Framework**: Bash-based custom test harness (helpers.sh)
- **Language**: POSIX bash with `set -uo pipefail` for strict mode
- **Assertion library**: Custom `check()` functions that count PASS/FAIL
- **Test organization**: Individual test files per component with aggregation via `run_all.sh`

### Test Utilities (tests/container/helpers.sh)
Helper functions for testing (sourced by all test scripts):
- `check()` — run a condition and record PASS/FAIL
- `check_cmd()` — verify command exists on PATH
- `check_file()` — verify a file exists
- `check_dir()` — verify a directory exists
- `check_contains()` — verify file contains regex pattern (grep -q)
- `check_not_contains()` — verify file does NOT contain pattern
- `summary()` — print PASS/FAIL counts and exit with code

### Linting
- **Tool**: ShellCheck
- **Severity**: --severity=warning
- **Files checked**: All test scripts and firewall scripts
- **Run via**: CI workflow (build-container.yml lint job)

## Test Location

```
tests/container/
├── helpers.sh              # Shared test utilities
├── run_all.sh              # Test runner
├── test_binaries.sh        # CLI tools and versions
├── test_neovim.sh          # Neovim plugins and Mason LSPs
├── test_pi.sh              # Pi agent config
├── test_opencode.sh        # OpenCode config and agents
├── test_tmux.sh            # tmux TPM and plugins
└── test_configs.sh         # Stowed dotfiles and Ollama URLs
```

## Test Coverage Areas

### test_binaries.sh
Verifies all essential CLI tools:
- **Core shell tools**: nvim, tmux, zsh, git, curl, wget, jq, fzf, fd, bat, eza, zoxide, lazygit, tv, stow, tree, rg
- **Neovim version**: Requires >= 0.11
- **Language runtimes**: go, cargo, node, npm, bun, pwsh, dotnet, python3, pip3
- **Dev tools**: gh, kubectl, kubectx, kubens, devcontainer, just, oh-my-posh
- **AI tools**: opencode, pi

### test_neovim.sh
Verifies lazy.nvim and Mason:
- **lazy.nvim directory** exists at ~/.local/share/nvim/lazy
- **51 plugins** from lazy-lock.json are cloned
- **15 Mason LSP servers** installed (ts_ls, html, cssls, pyright, gopls, bashls, etc.)
- **8 Mason tools** installed (prettier, stylua, eslint_d, shfmt, etc.)
- **Config files** stowed (init.lua, lazy.lua, mason.lua)
- **Headless startup** runs without errors

### test_pi.sh
Verifies Pi agent:
- **Pi binary** exists and --help exits cleanly
- **Config files** exist (models.json, settings.json)
- **Ollama URL validation**:
  - Contains 10.10.10.10:11434
  - Does NOT contain 127.0.0.1 or localhost
- **npm packages installed**:
  - @mariozechner/pi-coding-agent
  - @cmcconomy/pi-qwen-tool-parser
- **Settings references** qwen-tool-parser

### test_opencode.sh
Verifies opencode:
- **opencode binary** exists and --version exits cleanly
- **Config files** exist (config.json, oh-my-opencode.json)
- **10 agents**: hephaestus, oracle, librarian, explore, multimodal-looker, prometheus, metis, momus, atlas, sisyphus-junior
- **6 categories**: visual-engineering, ultrabrain, deep, artistry, quick, writing
- **Ollama URL validation**:
  - Contains 10.10.10.10:11434
  - Does NOT contain 127.0.0.1 or localhost

### test_tmux.sh
Verifies tmux TPM:
- **tmux binary** exists
- **TPM installed** at ~/.tmux/plugins/tpm
- **10 plugins** cloned (tmux-sensible, tmux-yank, tmux-resurrect, tmux-continuum, tmux-thumbs, tmux-fzf, tmux-fzf-url, tmux, tmux-sessionx, tmux-floax)
- **Config files** stowed (tmux.conf, tmux.reset.conf)

### test_configs.sh
Verifies stowed dotfiles:
- **Dotfiles stowed**:
  - ~/.config/nvim/init.lua
  - ~/.config/tmux/tmux.conf
  - ~/.zshrc
  - ~/.pi/agent/models.json
  - ~/.pi/agent/settings.json
  - ~/.opencode/config.json
  - ~/.opencode/oh-my-opencode.json
- **Ollama URL consistency**:
  - Both Pi and OpenCode use 10.10.10.10:11434
  - No localhost or 127.0.0.1
- **Default models set** in both configs
- **Default shell is zsh** (via getent passwd)

## How to Run Tests

### Via justfile
```bash
just test              # Build and run full suite
just test-one test_neovim.sh  # Run single test
just dev               # Interactive shell
```

### Via Docker
```bash
docker build -t dev-env:local .

# Run all tests
docker run --rm \
  -v "$(pwd)/tests/container:/tests/container:ro" \
  dev-env:local \
  bash /tests/container/run_all.sh

# Run single test
docker run --rm \
  -v "$(pwd)/tests/container:/tests/container:ro" \
  dev-env:local \
  bash /tests/container/test_neovim.sh

# Interactive
docker run -it --rm \
  -v "$(pwd):/workspace" \
  dev-env:local
```

### Manual (inside container)
```bash
source tests/container/helpers.sh
bash tests/container/test_binaries.sh
```

## CI/CD

### build-container.yml
**Triggers**: Pushes to master/feature/*, pull requests

**Jobs**:
1. **lint** — ShellCheck all test scripts (ubuntu-latest)
2. **build-and-test** — Build image and run test suite
   - Uses Docker Buildx
   - Caches layers via GitHub Actions cache
   - Mounts test scripts (read-only)
3. **publish** — Push to GHCR (master only after tests pass)
   - Tags: `:latest` and `:<git-sha>`
   - Repository: ghcr.io/ldj-share/dotfiles/dev-env

### test-firewall.yml
**Triggers**: Pushes/PRs to firewall scripts

**Jobs**:
1. **lint** — ShellCheck firewall scripts
2. **integration** — Run firewall tests (ubuntu:24.04 container)
   - NET_ADMIN and NET_RAW capabilities
   - Isolated network namespace
   - Tests: root checks, UFW setup, rules, idempotence, account hardening
   - Round-trip tests: enable → disable → enable
   - Confirms hardened final state

## Test Patterns

### Assertion Pattern
```bash
source "$(dirname "$0")/helpers.sh"

echo "=== Component: Category ==="
check_cmd tool_name
check_file /path/to/file
check_contains "label" /path/to/file "pattern"
check_not_contains "label" /path/to/file "bad_pattern"

summary
```

### Test Script Structure
1. Shebang and strict mode
2. Source helpers
3. Define paths/constants
4. Group tests by category with echo
5. Call check functions
6. Call summary() at end

### Error Handling
- Commands redirected to /dev/null for success/fail detection
- All tests run to completion (no early exit)
- summary() returns non-zero only if FAIL > 0

### Test Isolation
- Tests run in containers
- No state persists between runs
- Each file is independent
- Run order doesn't matter

### Code Quality
- ShellCheck validates all scripts (severity: warning)
- Shellcheck source directives document sourced files
- Standard bash idioms: [[, command -v, grep -q
