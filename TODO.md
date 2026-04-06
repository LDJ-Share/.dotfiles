# TODO

## Done

- [x] **PR #1 merged** — Ollama host architecture, firewall scripts, README, CI workflow
- [x] **dot-pi/settings.json** — removed `npm:@ollama/pi-web-search` (air-gapped, non-functional)
- [x] **dot-opencode/config.json** — updated baseURL to `http://10.10.10.10:11434/v1`
- [x] **Phase 1: Container test suite** — 6 test scripts in `tests/container/`
- [x] **Phase 2: Dockerfile** — 9-layer pre-initialized dev environment image
- [x] **Phase 3: build-container.yml** — lint → build+test → publish to GHCR pipeline

## In Progress

- [x] **PR #2 CI** — all 6 test scripts green, lint passes, ready to merge

## Containerization Remaining

- [ ] **Phase 4: Slim setup.sh** — once PR #2 merges
  - Remove all modules now handled by the container (system, neovim, shell, kubernetes,
    languages, dev-tools, vscode, claude, opencode, pi, dotfiles)
  - Keep: `module_docker` (needed to pull/run the container)
  - Add: `module_container` — `docker pull ghcr.io/ldj-share/.dotfiles/dev-env:latest`
  - Remove: `module_nvidia` (already excluded from MODULE_ORDER; delete entirely)

- [ ] **Phase 5: README final pass** — after setup.sh is slimmed
  - Update "What setup.sh Installs" module table
  - Add note about `devcontainer.json` for VS Code Remote integration

## Documentation

- [ ] **Additional documentation passes**
  - Pi agent setup details, model list rationale, per-model notes

## Infrastructure

- [ ] **Configure Windows host**
  - Create `OllamaNet` Hyper-V Internal Switch
  - Assign static IP `10.10.10.10/24` to host adapter
  - Install Ollama for Windows
  - Set system env var `OLLAMA_HOST=10.10.10.10:11434`
  - Add Windows Firewall inbound rule (TCP 11434, local address 10.10.10.10 only)
  - Pull all models listed in `dot-pi/models.json`

- [ ] **Configure VM and run setup.sh**
  - Install Docker (only real dependency now — `bash setup.sh --only docker`)
  - Attach OllamaNet adapter in Hyper-V Manager
  - Assign static IP `10.10.10.20/24`, no gateway, no DNS
  - Pull container: `docker pull ghcr.io/ldj-share/.dotfiles/dev-env:latest`
  - Verify: `docker run --rm dev-env:latest pi --version`

- [ ] **End-to-end test**
  - Launch Pi inside container, send a test prompt, confirm response from host Ollama
  - Confirm `curl http://10.10.10.10:11434` succeeds from inside the container
  - Confirm non-Ollama outbound traffic blocked by UFW

## Deployment

- [ ] **Pre-export hardening and VM export**
  - Remove Default Switch adapter from VM (Hyper-V Manager)
  - Run `sudo bash ~/.dotfiles/firewall-enable.sh` as root
  - Verify `sudo ufw status verbose` shows expected rules
  - Verify dev account cannot run `sudo echo test`
  - Shut down VM cleanly
  - Export VM image via Hyper-V Manager
