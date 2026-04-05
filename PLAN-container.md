# Plan: Containerized Dev Environment (GHCR Route)

## Goal

Replace `setup.sh`'s heavy per-tool installation with a single pre-built Docker image
published to GitHub Container Registry. Corporate machines only need to whitelist `ghcr.io`.

```
GitHub Actions (our network)
  └─ docker build  ← all apt/npm/cargo installs happen here
  └─ docker push ghcr.io/ldj-share/.dotfiles/dev-env:latest

Corporate VM (their network)
  └─ docker pull ghcr.io/ldj-share/.dotfiles/dev-env:latest  ← only outbound call
  └─ docker run -it -v ~/workspace:/workspace dev-env:latest
```

---

## What is NOT in the container

| Component | Why it stays on the VM host |
|---|---|
| Docker Engine | Needed to pull and run the container |
| Hyper-V / OllamaNet | Hypervisor-level; host OS only |
| `firewall-enable.sh` / UFW | Applies to VM network stack, not container |
| Ollama | Runs on Windows host with GPU access |

---

## Phase 0: Pre-container cleanup

Before writing any container code:

1. Merge PR #1 (CI is green).
2. Commit `dot-pi/settings.json` decision.
3. Fix `dot-opencode/config.json` baseURL → `http://10.10.10.10:11434/v1`
   (currently still `127.0.0.1` — missed in the PR).

---

## Phase 1: Test suite (write first)

Directory: `tests/container/`

Each test script is a standalone bash file that exits 0 on pass, non-zero on fail.
They are run by GitHub Actions against the built image *before* pushing to GHCR.

### `test_binaries.sh`
Verifies every expected CLI is on PATH and executes:
```
nvim, tmux, zsh, git, curl, jq, fzf, fd, bat, eza, zoxide, lazygit, tv,
go, cargo, node, bun, pwsh, dotnet, kubectl, kubectx, gh, devcontainer,
opencode, pi, just
```
Also checks `nvim --version` is >= 0.11.

### `test_neovim.sh`
- `~/.local/share/nvim/lazy/` exists and contains at least 10 plugin directories
  (lazy.nvim fully synced, not empty)
- `~/.local/share/nvim/mason/bin/` exists and contains key LSP binaries:
  `lua-language-server`, `typescript-language-server`, `pyright`, `gopls`,
  `rust-analyzer`, `stylua`, `black`, `prettier`
- Headless `nvim -c "lua print(vim.fn.stdpath('data'))" -c "qa"` exits 0

### `test_opencode.sh`
- `opencode --version` exits 0
- `~/.config/opencode/opencode.json` exists and contains `"oh-my-opencode"` string
  (confirms oh-my-opencode was installed and wrote into config)
- `~/.config/opencode/opencode.json` `baseURL` does NOT contain `127.0.0.1`
  (confirms URL was updated to 10.10.10.10)
- `oh-my-opencode` agent directories exist (hephaestus, oracle, etc.)

### `test_pi.sh`
- `pi --version` exits 0
- `~/.pi/agent/models.json` exists and `baseUrl` is `http://10.10.10.10:11434/v1`
- `~/.pi/agent/settings.json` exists
- Pi npm package directory exists (`~/.local/lib/node_modules/@mariozechner/pi-coding-agent`)
- Pi extension packages listed in `settings.json` are installed under the npm prefix

### `test_tmux.sh`
- `~/.tmux/plugins/tpm/` exists (TPM cloned)
- At least 2 additional plugin directories under `~/.tmux/plugins/`
  (confirming TPM ran and installed plugins from `tmux.conf`)

### `test_configs.sh`
- `~/.pi/agent/models.json` — `baseUrl` is `http://10.10.10.10:11434/v1`
- `~/.config/opencode/config.json` — `baseURL` is `http://10.10.10.10:11434/v1`
- `~/.config/opencode/oh-my-opencode.json` — no references to `127.0.0.1` or `localhost`
- `~/.config/nvim/init.lua` exists (nvim config stowed)
- `~/.zshrc` exists (shell config stowed)

---

## Phase 2: Dockerfile

Location: `Dockerfile` at repo root.

### Layer strategy

Each `RUN` layer is grouped by what it installs to maximize cache hits on rebuilds.
Dotfiles are copied late so that config changes don't bust the tool-install cache.

```
Stage 1 — base system packages (apt)
Stage 2 — create non-root user (dev, UID 1000)
Stage 3 — neovim AppImage (github release)
Stage 4 — shell tools (zoxide, eza, lazygit, television, oh-my-posh, bat, fzf)
Stage 5 — language runtimes (go, rust, node, bun, pwsh, dotnet)
Stage 6 — dev tools (gh, devcontainer, kubectl, kubectx)
Stage 7 — AI tools (opencode, oh-my-opencode, pi)
Stage 8 — copy dotfiles + stow
Stage 9 — pre-initialization (nvim headless, Mason LSPs, tmux TPM, pi init, opencode init)
```

### Key pre-initialization commands (Stage 9)

```dockerfile
# Neovim: install plugins + Mason LSPs headlessly
RUN nvim --headless -c "lua require('lazy').sync({wait=true, show=false})" -c "qa" 2>/dev/null || true
RUN nvim --headless -c "MasonInstall lua-language-server typescript-language-server \
    pyright gopls rust-analyzer stylua black prettier" -c "qa" 2>/dev/null || true

# tmux: clone TPM and install plugins headlessly
RUN git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm \
    && TMUX_PLUGIN_MANAGER_PATH=~/.tmux/plugins \
       ~/.tmux/plugins/tpm/scripts/install_plugins.sh

# Pi: trigger first-run initialization (downloads extensions from settings.json)
# Run with a no-op to initialize without starting the REPL
RUN pi --help >/dev/null 2>&1 || true
# If pi has a one-shot init command, use it; otherwise we rely on the npm install
# having run package post-install hooks

# opencode: oh-my-opencode already runs its install during setup;
# trigger opencode to download any lazy-loaded provider SDKs
RUN opencode --help >/dev/null 2>&1 || true
```

### Ollama URL
All configs must point to `http://10.10.10.10:11434/v1`, not `127.0.0.1`.
This is handled by the stowed config files (models.json, dot-opencode/config.json)
*after* the URL fix in Phase 0.

### User
Container runs as `dev` (UID 1000). Workspace is mounted at `/workspace` at runtime.

```dockerfile
CMD ["/bin/zsh"]
```

---

## Phase 3: GitHub Actions workflow

File: `.github/workflows/build-container.yml`

```
Trigger:
  push to master
  paths: Dockerfile, setup.sh, dot-pi/**, dot-opencode/**, nvim/**, tmux/**, zshrc/**, vsc-extensions.txt

Jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      1. checkout
      2. Set up QEMU (for multi-platform if needed)
      3. Set up Docker Buildx
      4. Build image (tag: dev-env:ci)
      5. Run each test script against the built image:
           docker run --rm dev-env:ci bash /tests/container/test_binaries.sh
           docker run --rm dev-env:ci bash /tests/container/test_neovim.sh
           ... etc.
      6. If all tests pass: log in to GHCR, push as:
           ghcr.io/ldj-share/.dotfiles/dev-env:latest
           ghcr.io/ldj-share/.dotfiles/dev-env:${sha}

  (Tests must pass before push — same pattern as test-firewall.yml)
```

### GHCR authentication
Uses `GITHUB_TOKEN` (automatic, no secret needed for packages in the same org).

---

## Phase 4: Slim down setup.sh

After the container workflow is in place and verified, `setup.sh` becomes:

```
module_docker  (unchanged — installs Docker Engine)
module_container  (new — docker pull + optional systemd service)

MODULE_ORDER=(docker container)
```

Everything else is removed. The Dockerfile is the canonical tool-install definition.

Old modules to delete: system, podman, neovim, shell, kubernetes, languages,
dev-tools, vscode, claude, opencode, pi, dotfiles

Note: `module_nvidia` was already excluded from MODULE_ORDER — remove it entirely.

---

## Phase 5: README updates

- Add "Corporate Environment Setup" section:
  - Prerequisites: Docker installed, `ghcr.io` whitelisted
  - Single command: `docker pull ghcr.io/ldj-share/.dotfiles/dev-env:latest`
  - Usage: `docker run -it -v ~/workspace:/workspace dev-env:latest`
- Update architecture ASCII diagram to show container layer
- Update pre-export checklist (no longer need to run setup.sh modules, just pull image)
- Keep business-leader section — air-gap and single-URL story is a strong sell

---

## Implementation order

```
Phase 0  →  Phase 1 (tests)  →  Phase 2 (Dockerfile)
         →  push branch, CI runs tests
         →  fix until tests pass
         →  Phase 3 (add push step to workflow)
         →  Phase 4 (slim setup.sh)
         →  Phase 5 (README)
```

Write the tests before the Dockerfile. If a test is hard to write, the pre-init
step it covers is probably ambiguous — clarify the requirement first.
