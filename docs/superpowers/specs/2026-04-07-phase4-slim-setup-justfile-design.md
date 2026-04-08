# Phase 4: Slim setup.sh, Justfile, Firewall SSH, devcontainer.json

**Date:** 2026-04-07
**Branch:** feature/containerize-dev-env
**Status:** Approved — ready for implementation

## Context

PR #2 (containerize-dev-env) is merged. The Dockerfile now provides the full dev
environment. `setup.sh` still installs everything — neovim, shell tools, all language
runtimes, AI tools — on the VM host, even though none of that is needed there anymore.
This phase slims `setup.sh` to reflect the VM's actual dependencies, wires up the
firewall for Remote-SSH, adds a `devcontainer.json` so VS Code finds the container
automatically, and adds `just` recipes for local container iteration.

---

## Section 1 — setup.sh

### MODULE_ORDER (default run)

```
system docker container
```

All other modules remain in setup.sh as callable functions but are removed from
`MODULE_ORDER`. They are available via `--only` for non-containerized environments.

**Removed from MODULE_ORDER:** `podman neovim shell kubernetes languages dev-tools
vscode claude opencode pi dotfiles`

**Optional modules (not in ORDER):** `podman`, `neovim`, `shell`, `kubernetes`,
`languages`, `dev-tools`, `vscode`, `claude`, `nvidia`, `opencode`, `pi`, `dotfiles`

### module_system (slimmed)

Only what the VM host needs to bootstrap Docker and stow dotfiles:

```
apt-transport-https  ca-certificates  curl  git  gnupg
lsb-release  openssh-server  software-properties-common  stow
```

Plus `systemctl enable --now ssh` to start and persist the SSH server.

All other packages previously in `module_system` (neovim, fzf, bat, ripgrep, python3,
tmux, zsh, etc.) are now exclusively in the Dockerfile.

### module_container (new)

```bash
module_container() {
  log "━━ Running module: container ━━"
  docker pull ghcr.io/ldj-share/.dotfiles/dev-env:latest
}
```

Pulls the pre-built image from GHCR after Docker is installed. This is the only
"install" step the VM host needs beyond Docker itself.

---

## Section 2 — firewall-enable.sh

Add one inbound rule after the loopback block, before the Ollama outbound rule:

```bash
# SSH inbound from Windows host — Remote-SSH and devcontainer workflows.
# Scoped to OllamaNet host IP only; response traffic handled by conntrack.
ufw allow in from "${OLLAMA_HOST_IP}" to any port 22 proto tcp
```

Update the summary log:
```
→ Inbound: ${OLLAMA_HOST_IP}:22/tcp  (Remote-SSH from Windows host)
```

`OLLAMA_HOST_IP` is already defined earlier in the script (`10.10.10.10`), so the rule
stays DRY. No other changes to the firewall script.

---

## Section 3 — justfile

Add to the existing justfile (keeping `default`, `synclocal`, `stow`; replacing the
current `install` recipe):

```justfile
# ── Setup ─────────────────────────────────────────────────────────────────────

# Bootstrap VM host environment (docker + container pull)
install:
    bash setup.sh

# Bootstrap full dev environment (all modules, for non-containerized use)
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

# Run a single test script (e.g. just test-one test_neovim.sh)
test-one script: build
    docker run --rm \
        -v "$(pwd)/tests/container:/tests/container:ro" \
        dev-env:local \
        bash /tests/container/{{script}}

# Open an interactive shell in the container with workspace mounted
dev:
    docker run -it --rm \
        -v "$(pwd):/workspace" \
        dev-env:local
```

---

## Section 4 — .devcontainer/devcontainer.json

New file at `.devcontainer/devcontainer.json`:

```json
{
  "name": "dev-env",
  "image": "ghcr.io/ldj-share/.dotfiles/dev-env:latest",
  "workspaceFolder": "/workspace",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind",
  "remoteUser": "dev"
}
```

Uses the pre-built GHCR image (already pulled by `module_container`) so VS Code does
not rebuild the image on each open. For local iteration, use `just build` / `just dev`.

**Windows host prerequisites (manual, one-time):** Install the **Remote - SSH** and
**Dev Containers** extensions in VS Code.

---

## What Is Not Changing

- `module_nvidia` — already excluded from MODULE_ORDER; remains in setup.sh as optional
- `module_claude` — remains in setup.sh as optional; not in MODULE_ORDER (offline env)
- `module_vscode` — remains in setup.sh as optional; VS Code runs on Windows host
- `module_podman` — remains in setup.sh as optional
- All container tests, Dockerfile, and CI workflow — no changes in this phase
- `firewall-disable.sh` — no changes needed
