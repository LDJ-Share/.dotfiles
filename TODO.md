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

- [x] **Phase 4: Slim setup.sh** — merged in PR #2
  - `module_system` slimmed to VM-host-only packages + openssh-server
  - `module_container` added (docker pull from GHCR)
  - `MODULE_ORDER` slimmed to system/docker/container
  - Base dev packages moved to `module_shell` for non-containerized use

- [x] **Phase 5: README final pass**
  - Updated "What setup.sh Installs" module table
  - Added VS Code Remote Development section (Remote-SSH + Dev Containers)
  - Updated firewall docs and security table to reflect SSH inbound rule

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
