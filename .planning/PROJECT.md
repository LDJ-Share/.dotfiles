# Air-Gapped AI Dev Environment — Compose-First Deployment

## What This Is

A hardened, all-in-one AI coding environment deployable as a docker-compose stack into air-gapped machines. The stack pairs an existing dev container (Neovim, Pi, OpenCode, full toolchain) with a co-deployed Ollama container on an internal Docker network — no firewall holes, no external internet after initial pull. Supports VS Code devcontainer workflow, Podman, and CPU/GPU machines.

## Core Value

A developer on an air-gapped machine can open VS Code, reopen in devcontainer, and immediately have a full AI coding session — with no setup, no internet, and no firewall exceptions.

## Requirements

### Validated

<!-- Shipped and confirmed valuable — inferred from existing codebase -->

- ✓ Dev container image published to GHCR with full toolchain — existing
- ✓ Multi-stage Docker build (parallel builders: neovim, shell tools, go, rust, bun, dotnet, ai-tools) — existing
- ✓ Neovim with LSP, DAP, treesitter, plugins pre-initialized — existing
- ✓ Pi + OpenCode AI tools pre-configured for Ollama — existing
- ✓ 4-layer security model (UFW, sudo removal, kernel-level firewall, account hardening) — existing
- ✓ GNU Stow dotfiles management — existing
- ✓ GitHub Actions CI/CD (build, test, publish to GHCR) — existing
- ✓ Container test suite (binaries, neovim, tmux, pi, opencode, configs) — existing
- ✓ Offline import workflow scripts: `image-import.sh` / `image-import.ps1` verify the bundle, restore images, validate compose, and handle optional CUDA payloads — validated in Phase 05

### Active

<!-- Current scope — this milestone -->

- [ ] Ollama container image pre-baked with `gemma4:26b` + `gemma4:e4b`, published to GHCR; manual model pull is the temporary fallback while hosted-runner publish remains blocked
- [ ] `docker-compose.yml` bridging dev container + ollama container on internal Docker network
- [ ] `.devcontainer/` updated to use docker-compose (compose-first replaces direct host Ollama)
- [ ] Windows host Ollama mode (`10.10.10.10:11434`) still functional as fallback
- [ ] GPU optional in compose (`deploy: resources` with NVIDIA if present, CPU fallback)
- [ ] Compose file compatible with both `docker compose` and `podman compose`
- [ ] Export/import workflow scripts: `image-export.sh` / `image-export.ps1` (save → archive → transport)
- [ ] Import workflow scripts: `image-import.sh` / `image-import.ps1` (load from archive into WSL2)
- [ ] Example workspace template (docker-compose.yml + .devcontainer users copy into their project)

### Out of Scope

- Corporate Harbor registry integration — defer until compose workflow is validated in field
- Ollama running inside the dev container itself — GPU isolation requires separate container
- Kubernetes/Helm deployment — not needed for single-developer air-gap use case
- macOS/Linux host support — Windows + WSL2/Hyper-V is the target platform

## Context

**Deployment modes supported (priority order):**
1. docker-compose in WSL2 (primary — this milestone)
2. docker-compose in Linux VM
3. Direct Ubuntu VM via `setup.sh` (existing)

**Air-gap constraint:** All container images must be fully pre-initialized before export. No runtime pulls from registries, package managers, or model hubs. Models baked into the Ollama image at build time. Until GHCR publication is unblocked, a connected staging machine may manually pull the required Ollama models before export.

**Podman note:** Windows host has Podman Desktop (not Docker Desktop). The compose file must work with `podman compose`. Air-gapped target machine uses Docker in WSL2 directly (no Desktop).

**Network topology change:** Current architecture routes AI traffic through `10.10.10.10:11434` (Windows host Ollama via Hyper-V internal switch). New compose approach puts Ollama in a sidecar container on an internal Docker bridge network — no host firewall rules needed. Host Ollama path remains available via env var override.

**Reference implementation:** `C:\Users\matth\source\repos\claude-code-try-again` — existing docker-compose + devcontainer example to study.

## Constraints

- **Air-gap**: All dependencies must be baked in at build time — no runtime internet access after export
- **Portability**: Must work on machines with no Docker Desktop, no GUI docker tooling
- **Compatibility**: Compose file must run under both `docker compose` v2 and `podman compose`
- **GPU**: Optional NVIDIA passthrough — must degrade gracefully to CPU
- **Models**: gemma4:26b (~17GB) + gemma4:e4b (~5GB) → ~22GB minimum disk on air-gapped machine
- **Registry**: Images published to GHCR alongside existing dev-env image

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Ollama as separate container in compose | GPU isolation, keeps dev container clean, standard pattern | — Pending |
| Keep host Ollama as fallback | Not everyone has WSL2/Docker, Hyper-V path still valid | — Pending |
| Bake models into Ollama image | Air-gap requirement — no pull at runtime | — Pending |
| Manual model pull is an acceptable temporary fallback | GitHub-hosted runner disk limits blocked the GHCR publish path in run `24223620363`; Phase 2 still needs a usable Ollama source | Accepted on 2026-04-10 |
| Replace .devcontainer with compose-based version | Simplify primary use case; old approach was workaround | — Pending |
| Podman + Docker compat | Host has Podman Desktop; target uses Docker in WSL2 | — Pending |
| Import validates first, starts later | Offline restore should verify checksum, image availability, and compose syntax without implicitly starting services | Accepted in Phase 05 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-10 after Phase 5 import workflow completion*
