# Phase 4: Slim setup.sh, Justfile, Firewall SSH, devcontainer.json — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Slim setup.sh down to only what the VM host needs (docker + SSH + container pull), add SSH access to the hardened firewall, expose `just` recipes for install variants and local container iteration, and add a `devcontainer.json` for VS Code.

**Architecture:** Four independent file edits — setup.sh, firewall-enable.sh, justfile, and a new .devcontainer/devcontainer.json — plus a committed spec doc. No new abstractions; each change is a targeted in-place edit.

**Tech Stack:** bash, just, Docker, UFW, VS Code devcontainer spec

---

## File Map

| File | Action | What changes |
|---|---|---|
| `docs/superpowers/specs/2026-04-07-phase4-slim-setup-justfile-design.md` | Commit (already written) | — |
| `setup.sh` | Modify | Slim `module_system`, add `module_container`, update `MODULE_ORDER` and "next steps" |
| `firewall-enable.sh` | Modify | Add SSH inbound rule from `10.10.10.10`; update summary log |
| `justfile` | Modify | Replace `install`; add `install-full`, `install-only`, `build`, `test`, `test-one`, `dev` |
| `.devcontainer/devcontainer.json` | Create | devcontainer pointing at GHCR image |

---

## Task 1: Commit the design spec

**Files:**
- Commit: `docs/superpowers/specs/2026-04-07-phase4-slim-setup-justfile-design.md`

- [ ] **Step 1: Verify the file exists**

```bash
ls docs/superpowers/specs/2026-04-07-phase4-slim-setup-justfile-design.md
```

Expected: file path printed, no error.

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-04-07-phase4-slim-setup-justfile-design.md
git commit -m "docs: add Phase 4 design spec (slim setup.sh, justfile, firewall SSH, devcontainer)"
```

---

## Task 2: Slim module_system in setup.sh

`module_system` currently installs ~30 packages plus python tools, bat, and an fzf upgrade — all of which are in the Dockerfile. The VM host only needs the packages required to bootstrap Docker and stow dotfiles.

**Files:**
- Modify: `setup.sh:103-174`

- [ ] **Step 1: Replace module_system body**

Find this entire block (lines 103–174):

```bash
module_system() {
  log "━━ Running module: system ━━"

  log "Updating apt and installing base packages..."
  apt_update
  apt_install \
    apt-transport-https \
    build-essential \
    ...
  # (all the way through the bat install block)
}
```

Replace it with:

```bash
# ═════════════════════════════════════════════════════════════════════════════
# MODULE: system
# Installs the minimal base packages the VM host needs to bootstrap Docker
# and stow dotfiles. All dev tools (neovim, shell utilities, languages, etc.)
# live in the container image — nothing extra is needed here.
# ═════════════════════════════════════════════════════════════════════════════
module_system() {
  log "━━ Running module: system ━━"

  log "Updating apt and installing base packages..."
  apt_update
  apt_install \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    gnupg \
    lsb-release \
    openssh-server \
    software-properties-common \
    stow

  # Enable and start the SSH server so Remote-SSH and devcontainer workflows
  # work from the Windows host over the OllamaNet switch (10.10.10.10 → VM).
  sudo systemctl enable --now ssh
  log "SSH server enabled."
}
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n setup.sh
```

Expected: no output (clean parse).

---

## Task 3: Add module_container, update MODULE_ORDER, update "next steps"

**Files:**
- Modify: `setup.sh` — add `module_container` after `module_docker`; update `MODULE_ORDER` at line 768; update "next steps" section at lines 777–794

- [ ] **Step 1: Add module_container after module_docker**

Find the line:

```bash
# ═════════════════════════════════════════════════════════════════════════════
# MODULE: podman
```

Insert this block immediately before it:

```bash
# ═════════════════════════════════════════════════════════════════════════════
# MODULE: container
# Pulls the pre-built dev environment image from GHCR. Requires Docker to be
# installed first (module_docker). After this, the full dev environment is
# available via: docker run -it --rm -v ~/workspace:/workspace dev-env:latest
# ═════════════════════════════════════════════════════════════════════════════
module_container() {
  log "━━ Running module: container ━━"
  docker pull ghcr.io/ldj-share/.dotfiles/dev-env:latest
  log "Container image pulled. Run with: docker run -it --rm -v ~/workspace:/workspace ghcr.io/ldj-share/.dotfiles/dev-env:latest"
}

```

- [ ] **Step 2: Update MODULE_ORDER and its comment block**

Find:

```bash
# nvidia is excluded from the default run order — Ollama runs on the Windows
# host in the standard Hyper-V deployment, so GPU drivers in the VM are not
# needed. See the nvidia module header for when to include it.
#
# Firewall lockdown and account hardening are handled separately by:
#   sudo bash firewall-enable.sh   (run as root, final step before VM export)
#   sudo bash firewall-disable.sh  (run as root, opens a maintenance window)
MODULE_ORDER=(system docker podman neovim shell kubernetes languages dev-tools vscode claude opencode pi dotfiles)
```

Replace with:

```bash
# Default run order — VM host bootstrap only.
# Installs the base system packages, Docker, and pulls the dev container image.
# All dev tools (neovim, shell, languages, AI agents, etc.) live in the image.
#
# Optional modules (not in default order — invoke with --only):
#   podman      Podman Desktop via Flatpak
#   neovim      Neovim + plugins (non-containerized use)
#   shell       Shell tools: zoxide, eza, lazygit, oh-my-posh, tv (non-containerized)
#   kubernetes  kubectl, kubectx, kubens (non-containerized)
#   languages   Go, Rust, Node.js, Bun, PowerShell, .NET (non-containerized)
#   dev-tools   gh CLI, devcontainer CLI, just (non-containerized)
#   vscode      VS Code extensions — VS Code runs on the Windows host, not the VM
#   claude      Claude Code CLI — for non-air-gapped environments only
#   nvidia      NVIDIA drivers + CUDA — only if running Ollama inside the VM
#   opencode    OpenCode + oh-my-opencode (non-containerized)
#   pi          Pi coding agent (non-containerized)
#   dotfiles    Stow all dotfiles to home directory
#
# Firewall lockdown and account hardening are handled separately by:
#   sudo bash firewall-enable.sh   (run as root, final step before VM export)
#   sudo bash firewall-disable.sh  (run as root, opens a maintenance window)
MODULE_ORDER=(system docker container)
```

- [ ] **Step 3: Update "next steps" section**

Find:

```bash
echo "Next steps:"
echo "  1. Launch wezterm (select JetBrains Mono Nerd Font if not auto-selected)."
echo "  2. Start tmux and press Ctrl-A + I to install plugins."
echo "  3. Open nvim and run :Lazy sync if plugins weren't installed headlessly."
echo "  4. Load opencode once to download plugins: opencode"
echo "  5. Load pi once to download plugins."
echo "  6. Clone https://github.com/LDJ-Share/pi-agent-orchestrator-extension and follow README."
echo ""
echo "  Before exporting the VM for air-gapped deployment:"
echo "  7. Verify Pi can reach Ollama: curl http://10.10.10.10:11434"
echo "  8. Remove the Default Switch network adapter in Hyper-V Manager."
echo "  9. Run the firewall and account hardening script (as root):"
echo "       sudo bash ~/.dotfiles/firewall-enable.sh"
```

Replace with:

```bash
echo "Next steps:"
echo "  1. Start the dev container:"
echo "       docker run -it --rm -v ~/workspace:/workspace ghcr.io/ldj-share/.dotfiles/dev-env:latest"
echo "  2. From VS Code on the Windows host, use Remote-SSH to connect to this VM,"
echo "     then reopen the workspace in the dev container (Dev Containers extension)."
echo ""
echo "  Before exporting the VM for air-gapped deployment:"
echo "  3. Verify the container can reach Ollama:"
echo "       docker run --rm ghcr.io/ldj-share/.dotfiles/dev-env:latest curl -s http://10.10.10.10:11434"
echo "  4. Remove the Default Switch network adapter in Hyper-V Manager."
echo "  5. Run the firewall and account hardening script (as root):"
echo "       sudo bash ~/.dotfiles/firewall-enable.sh"
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n setup.sh
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add setup.sh
git commit -m "feat: slim setup.sh for containerized VM (Phase 4)"
```

---

## Task 4: Add SSH inbound rule to firewall-enable.sh

**Files:**
- Modify: `firewall-enable.sh:101-116`

- [ ] **Step 1: Add SSH rule after loopback rules**

Find this exact block (lines 101–107):

```bash
# Loopback traffic must always be permitted — many local services depend on it.
ufw allow in  on lo
ufw allow out on lo

# The only permitted outbound path: the Ollama API on the Hyper-V host.
# All AI inference traffic flows through this single, controlled channel.
ufw allow out to "${OLLAMA_HOST_IP}" port "${OLLAMA_PORT}" proto tcp
```

Replace with:

```bash
# Loopback traffic must always be permitted — many local services depend on it.
ufw allow in  on lo
ufw allow out on lo

# SSH inbound from the Windows host only — used for Remote-SSH and devcontainer
# workflows. Scoped to the OllamaNet host IP; response traffic is handled
# automatically by UFW's connection tracking (ESTABLISHED rules in before.rules).
ufw allow in from "${OLLAMA_HOST_IP}" to any port 22 proto tcp

# The only permitted outbound path: the Ollama API on the Hyper-V host.
# All AI inference traffic flows through this single, controlled channel.
ufw allow out to "${OLLAMA_HOST_IP}" port "${OLLAMA_PORT}" proto tcp
```

- [ ] **Step 2: Update the summary log**

Find:

```bash
log "UFW active. Permitted traffic:"
log "  → Outbound: ${OLLAMA_HOST_IP}:${OLLAMA_PORT}/tcp  (Ollama on Hyper-V host)"
log "  ↔ Loopback: unrestricted"
log "  ✗ All other inbound and outbound: DENIED"
```

Replace with:

```bash
log "UFW active. Permitted traffic:"
log "  ← Inbound:  ${OLLAMA_HOST_IP}:22/tcp              (Remote-SSH from Windows host)"
log "  → Outbound: ${OLLAMA_HOST_IP}:${OLLAMA_PORT}/tcp  (Ollama on Hyper-V host)"
log "  ↔ Loopback: unrestricted"
log "  ✗ All other inbound and outbound: DENIED"
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n firewall-enable.sh
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add firewall-enable.sh
git commit -m "feat: allow SSH inbound from Windows host in hardened firewall"
```

---

## Task 5: Update justfile

**Files:**
- Modify: `justfile`

- [ ] **Step 1: Replace the full justfile content**

```justfile
# https://just.systems

default:
    @just --list

synclocal:
    git push local master

stow:
    stow .

# ── Setup ─────────────────────────────────────────────────────────────────────

# Bootstrap VM host environment (docker + container pull)
install:
    bash setup.sh

# Bootstrap full dev environment — all modules, for non-containerized use
install-full:
    bash setup.sh --only system docker podman neovim shell kubernetes languages dev-tools vscode claude opencode pi dotfiles

# Run specific modules only (e.g. just install-only docker neovim)
install-only *modules:
    bash setup.sh --only {{modules}}

# ── Container ─────────────────────────────────────────────────────────────────

# Build the container image locally
build:
    docker build -t dev-env:local .

# Build then run the full test suite
test: build
    docker run --rm \
        -v "$(pwd)/tests/container:/tests/container:ro" \
        dev-env:local \
        bash /tests/container/run_all.sh

# Run a single test script against the locally built image (e.g. just test-one test_neovim.sh)
test-one script: build
    docker run --rm \
        -v "$(pwd)/tests/container:/tests/container:ro" \
        dev-env:local \
        bash /tests/container/{{script}}

# Open an interactive shell in the locally built container with workspace mounted
dev:
    docker run -it --rm \
        -v "$(pwd):/workspace" \
        dev-env:local
```

- [ ] **Step 2: Verify justfile is parseable**

```bash
just --list
```

Expected output (order may vary):
```
Available recipes:
    build          # Build the container image locally
    dev            # Open an interactive shell in the locally built container with workspace mounted
    default
    install        # Bootstrap VM host environment (docker + container pull)
    install-full   # Bootstrap full dev environment — all modules, for non-containerized use
    install-only   # Run specific modules only (e.g. just install-only docker neovim)
    stow           # ...
    synclocal      # ...
    test           # Build then run the full test suite
    test-one       # Run a single test script against the locally built image
```

- [ ] **Step 3: Commit**

```bash
git add justfile
git commit -m "feat: add container build/test/dev recipes and install variants to justfile"
```

---

## Task 6: Create .devcontainer/devcontainer.json

**Files:**
- Create: `.devcontainer/devcontainer.json`

- [ ] **Step 1: Create the directory and file**

Create `.devcontainer/devcontainer.json` with this exact content:

```json
{
  "name": "dev-env",
  "image": "ghcr.io/ldj-share/.dotfiles/dev-env:latest",
  "workspaceFolder": "/workspace",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind",
  "remoteUser": "dev"
}
```

- [ ] **Step 2: Verify it is valid JSON**

```bash
python3 -c "import json,sys; json.load(open('.devcontainer/devcontainer.json')); print('valid JSON')"
```

Expected: `valid JSON`

- [ ] **Step 3: Commit**

```bash
git add .devcontainer/devcontainer.json
git commit -m "feat: add devcontainer.json for VS Code Remote-SSH + Dev Containers workflow"
```

---

## Task 7: Verify local container workflow

Run this task on a machine with Docker installed (Windows with Docker Desktop, or the VM after `just install`).

**Files:** none — verification only

- [ ] **Step 1: Verify just --list shows all new recipes**

```bash
just --list
```

Expected: `build`, `test`, `test-one`, `dev`, `install`, `install-full`, `install-only` all appear.

- [ ] **Step 2: Build the image locally**

```bash
just build
```

Expected: `docker build` output ending with `=> => naming to docker.io/library/dev-env:local`. Takes ~10–20 min on first run (no cache); much faster with layer cache.

- [ ] **Step 3: Run the full test suite against the local image**

```bash
just test
```

Expected: all test scripts pass, output ends with lines like:
```
=== Summary ===
PASSED: N
FAILED: 0
```

- [ ] **Step 4: Verify a single test works**

```bash
just test-one test_binaries.sh
```

Expected: binary checks pass, no FAILED lines.

- [ ] **Step 5: Spot-check the interactive shell**

```bash
just dev
```

Expected: drops into a `zsh` shell as the `dev` user with `/workspace` mounted. Type `exit` to leave.

---

## Post-implementation checklist

- [ ] `bash -n setup.sh` — clean
- [ ] `bash -n firewall-enable.sh` — clean
- [ ] `just --list` — all 9 recipes shown
- [ ] `just test` — all test scripts green (requires Docker)
- [ ] Push branch and verify CI passes on GitHub Actions
