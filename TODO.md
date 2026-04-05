# TODO

## Done

- [x] **1. PR #1 CI — both lint and integration jobs passed**

## In Progress

- [ ] **2. Merge PR #1 into master**
  - Branch: `feature/ollama-host-network-isolation`
  - Both CI jobs green — ready to merge

## Pre-Container Cleanup

- [ ] **3. Resolve `dot-pi/settings.json` change**
  - Pre-existing unstaged change removes `npm:@ollama/pi-web-search` from Pi packages
  - Decide: intentional removal → commit it; unintentional → restore it

- [ ] **4. Fix `dot-opencode/config.json` Ollama URL**
  - Currently points to `http://127.0.0.1:11434/v1`
  - Must match Pi: change to `http://10.10.10.10:11434/v1`
  - Commit to master (separate from PR #1)

## Containerization (GHCR Route)

Goal: single `docker pull ghcr.io/ldj-share/.dotfiles/dev-env:latest` — one URL to whitelist.
See PLAN-container.md for full design.

- [ ] **5. Write container test suite first (TDD)**
  - `tests/container/test_binaries.sh` — all expected CLIs exist
  - `tests/container/test_neovim.sh` — lazy plugins + Mason LSPs pre-installed
  - `tests/container/test_opencode.sh` — opencode + oh-my-opencode agents present
  - `tests/container/test_pi.sh` — pi command works, packages present
  - `tests/container/test_tmux.sh` — TPM plugins installed
  - `tests/container/test_configs.sh` — all configs point to `10.10.10.10:11434`

- [ ] **6. Write Dockerfile**
  - Layers: base → user → system tools → languages → dev tools (opencode, pi) → dotfiles → pre-init
  - Pre-init: nvim headless sync, Mason LSP install, tmux TPM install, Pi init, opencode/oh-my-opencode init
  - All configs baked in: no lazy loading on first launch

- [ ] **7. Write `.github/workflows/build-container.yml`**
  - Trigger: push to master when Dockerfile or dotfiles change
  - Build → run test suite → push to `ghcr.io/ldj-share/.dotfiles/dev-env:latest`

- [ ] **8. Slim down `setup.sh`**
  - Remove all modules now handled by the container
  - Keep: Docker install (needed to pull/run the container)
  - Add: `docker pull ghcr.io/ldj-share/.dotfiles/dev-env:latest`

- [ ] **9. Update README**
  - Add container usage section (corporate environment workflow)
  - Update architecture diagram: container layer between VM and tools
  - Document single URL whitelist requirement: `ghcr.io`

## Documentation

- [ ] **10. Complete additional documentation passes**
  - Pi agent setup details, model list rationale, per-model notes

## Infrastructure (post-container)

- [ ] **11. Configure Windows host**
  - Create `OllamaNet` Hyper-V Internal Switch
  - Assign static IP `10.10.10.10/24` to host adapter
  - Install Ollama for Windows
  - Set system env var `OLLAMA_HOST=10.10.10.10:11434`
  - Add Windows Firewall inbound rule (TCP 11434, local address 10.10.10.10 only)
  - Pull all models listed in `dot-pi/models.json`

- [ ] **12. Configure VM and run setup.sh**
  - Install Docker (only real dependency now)
  - Attach OllamaNet adapter in Hyper-V Manager
  - Assign static IP `10.10.10.20/24`, no gateway, no DNS
  - Run `bash setup.sh` (pulls container image)
  - Verify `docker run ... pi` can reach `http://10.10.10.10:11434`

- [ ] **13. End-to-end test**
  - Launch Pi inside container, send a test prompt, confirm response from host Ollama
  - Confirm `curl http://10.10.10.10:11434` succeeds from container
  - Confirm non-Ollama outbound traffic blocked by UFW

## Deployment

- [ ] **14. Pre-export hardening and VM export**
  - Remove Default Switch adapter from VM (Hyper-V Manager)
  - Run `sudo bash ~/.dotfiles/firewall-enable.sh` as root
  - Verify `sudo ufw status verbose` shows expected rules
  - Verify dev account cannot run `sudo echo test`
  - Shut down VM cleanly
  - Export VM image via Hyper-V Manager
