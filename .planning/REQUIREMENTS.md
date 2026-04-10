# Requirements: Air-Gapped AI Dev Environment — Compose-First Deployment

**Defined:** 2026-04-08
**Core Value:** A developer on an air-gapped machine can open VS Code, reopen in devcontainer, and immediately have a full AI coding session — with no setup, no internet, and no firewall exceptions.

## v1 Requirements

### Ollama Container

- [ ] **OLLAMA-01**: Ollama container image pre-baked with `gemma4:26b` and `gemma4:e4b` models, published to GHCR
- [ ] **OLLAMA-02**: Ollama container supports NVIDIA GPU passthrough when available; degrades gracefully to CPU when not
- [ ] **OLLAMA-03**: Ollama container's `OLLAMA_HOST` bound to `0.0.0.0:11434` for internal network accessibility
- [ ] **OLLAMA-04**: GitHub Actions workflow builds and publishes the Ollama image to GHCR on changes

### Compose

- [ ] **COMPOSE-01**: `docker-compose.yml` defines `dev-env` and `ollama` services on an isolated internal bridge network
- [ ] **COMPOSE-02**: Dev-env service resolves Ollama by service hostname (`OLLAMA_HOST` defaults to `http://ollama:11434`)
- [ ] **COMPOSE-03**: `OLLAMA_HOST` env var override allows switching to Windows host Ollama at `10.10.10.10:11434`
- [ ] **COMPOSE-04**: Compose file includes `x-podman` extension block; compatible with both `docker compose` v2 and `podman compose`
- [ ] **COMPOSE-05**: Ollama service health check (`GET /api/tags`) gates `dev-env` startup via `depends_on: condition: service_healthy`

### Devcontainer

- [ ] **DEV-01**: `.devcontainer/devcontainer.json` updated to use `dockerComposeFile` pointing to compose file in `.devcontainer/`
- [ ] **DEV-02**: `devcontainer.json` correctly sets `service: dev-env`, `workspaceFolder: /workspace`, `remoteUser: dev`
- [ ] **DEV-03**: `devcontainer.json` starts both `dev-env` and `ollama` via `runServices`

### Export Scripts

- [ ] **EXPORT-01**: `image-export.sh` saves all compose images to a single gzipped tarball with SHA256 checksum
- [ ] **EXPORT-02**: `image-export.ps1` PowerShell equivalent for Windows host export workflow
- [ ] **EXPORT-03**: Export produces `manifest.json` containing image names, tags, digests, checksums, and CUDA installer list
- [ ] **EXPORT-04**: Export script bundles any CUDA/driver installers downloaded by `cuda-prep` into the transport archive

### CUDA Preparation

- [ ] **CUDA-01**: `cuda-prep.sh` + `cuda-prep.ps1` accept offline machine's GPU model, driver version, and OS; download matching CUDA toolkit + nvidia-container-toolkit for Linux (WSL2/VM target)
- [ ] **CUDA-02**: `cuda-prep` also downloads the correct Windows NVIDIA driver installer for the specified GPU model
- [ ] **CUDA-03**: Scripts include inline comments with exact commands to run on the offline machine to retrieve required info (GPU model, driver version, kernel version, OS release)

### Import Scripts

- [ ] **IMPORT-01**: `image-import.sh` verifies SHA256, loads images via `docker load`, validates compose syntax, reports service status
- [ ] **IMPORT-02**: `image-import.ps1` PowerShell equivalent for Windows host import workflow
- [ ] **IMPORT-03**: If CUDA/driver installers are present in archive, import script installs them; if GPU config exists but no installers found, warns with instructions to re-run `cuda-prep`

### Workspace Template

- [ ] **TMPL-01**: Example workspace template (`.devcontainer/` + `docker-compose.yml`) provided for users to copy into their own project
- [ ] **TMPL-02**: Template includes inline documentation covering the full air-gap deployment workflow (export → transport → import → open in VS Code)

## v2 Requirements

### Distribution

- **DIST-01**: Per-image tarball option for partial updates (update only Ollama or only dev-env)
- **DIST-02**: zstd compression support for faster export/import
- **DIST-03**: Corporate Harbor registry integration for enterprise distribution
- **DIST-04**: Multi-architecture support (ARM64 + x86_64)

### Security

- **SEC-01**: Sigstore image signing for transport artifact verification

## Out of Scope

| Feature | Reason |
|---------|--------|
| Kubernetes/Helm deployment | Not needed for single-developer air-gap; adds complexity without value for this use case |
| macOS/Linux host support | Windows + WSL2/Hyper-V is the target platform; other hosts are future |
| Ollama inside dev container | GPU isolation requires separate container; combining breaks the security model |
| Automated model validation/benchmarking | Scope creep; model quality is managed by model selection, not runtime testing |
| Real-time model streaming optimization | Ollama handles this; not a compose/deployment concern |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| OLLAMA-01 | Phase 1 | Implemented, unpublished |
| OLLAMA-02 | Phase 1 | Implemented, unpublished |
| OLLAMA-03 | Phase 1 | Implemented, unpublished |
| OLLAMA-04 | Phase 1 | Blocked by GitHub-hosted runner disk limits |
| COMPOSE-01 | Phase 2 | Pending |
| COMPOSE-02 | Phase 2 | Pending |
| COMPOSE-03 | Phase 2 | Pending |
| COMPOSE-04 | Phase 2 | Pending |
| COMPOSE-05 | Phase 2 | Pending |
| DEV-01 | Phase 3 | Pending |
| DEV-02 | Phase 3 | Pending |
| DEV-03 | Phase 3 | Pending |
| EXPORT-01 | Phase 4 | Pending |
| EXPORT-02 | Phase 4 | Pending |
| EXPORT-03 | Phase 4 | Pending |
| EXPORT-04 | Phase 4 | Pending |
| CUDA-01 | Phase 4 | Pending |
| CUDA-02 | Phase 4 | Pending |
| CUDA-03 | Phase 4 | Pending |
| IMPORT-01 | Phase 5 | Pending |
| IMPORT-02 | Phase 5 | Pending |
| IMPORT-03 | Phase 5 | Pending |
| TMPL-01 | Phase 6 | Pending |
| TMPL-02 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-08*
*Last updated: 2026-04-10 after Phase 1 block assessment*
