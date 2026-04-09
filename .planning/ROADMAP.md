# Roadmap: Air-Gapped AI Dev Environment — Compose-First Deployment

**Phases:** 6
**Requirements:** 24 v1
**Generated:** 2026-04-08

## Phase Overview

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 1 | Ollama Image | Pre-baked Ollama image with models published to GHCR | OLLAMA-01, OLLAMA-02, OLLAMA-03, OLLAMA-04 | Image pulls and serves models; GPU/CPU fallback confirmed; CI workflow publishes to GHCR |
| 2 | Compose Stack | Two-service compose stack with health-gated startup | COMPOSE-01, COMPOSE-02, COMPOSE-03, COMPOSE-04, COMPOSE-05 | `docker compose up` starts both services; dev-env resolves ollama by hostname; podman compose also works |
| 3 | Devcontainer Integration | VS Code reopen-in-container launches full compose stack | DEV-01, DEV-02, DEV-03 | VS Code reopen triggers both services; workspace mounts correctly; AI tools reach Ollama |
| 4 | Export Scripts + CUDA Prep | Transport archive produced with manifest + CUDA installers bundled | EXPORT-01, EXPORT-02, EXPORT-03, EXPORT-04, CUDA-01, CUDA-02, CUDA-03 | Single tar.gz with SHA256 created; manifest.json present; CUDA/driver installers bundled |
| 5 | Import Scripts | Archive verified and loaded on air-gapped machine | IMPORT-01, IMPORT-02, IMPORT-03 | SHA256 verified; images loaded; compose syntax validated; CUDA/driver installers applied |
| 6 | Workspace Template | Copyable template with full inline workflow documentation | TMPL-01, TMPL-02 | Template copied to new project; reopen-in-container works; air-gap workflow documented end-to-end |

---

## Phase Details

### Phase 1: Ollama Image

**Goal:** Build and publish a pre-baked Ollama container image containing gemma4:26b and gemma4:e4b models, with GPU/CPU detection, ready for compose integration.

**Requirements:**
- OLLAMA-01: Ollama container image pre-baked with `gemma4:26b` and `gemma4:e4b` models, published to GHCR
- OLLAMA-02: Ollama container supports NVIDIA GPU passthrough when available; degrades gracefully to CPU when not
- OLLAMA-03: Ollama container's `OLLAMA_HOST` bound to `0.0.0.0:11434` for internal network accessibility
- OLLAMA-04: GitHub Actions workflow builds and publishes the Ollama image to GHCR on changes

**Success Criteria:**
1. `docker run ghcr.io/.../ollama-models:latest` serves `GET /api/tags` returning both gemma4 models without any internet access
2. Container starts and serves on CPU when no NVIDIA device is present; starts with GPU when `nvidia-container-toolkit` is installed and a GPU is detected
3. GitHub Actions workflow completes and the image tag appears in GHCR within the CI run

**Notes:** Models are 22GB+ combined. Use `ollama serve & sleep 10` with a health-check retry loop inside the Dockerfile RUN layer before model pulls. Use BuildKit GHA cache (`--cache-from type=gha`) scoped per model layer to avoid 30+ minute full rebuilds on every CI run. GHCR single-layer limit is 10GB — document expected multi-layer push behavior. Do not use `device_requests` (deprecated); use `deploy.resources.reservations.devices` in compose.

---

### Phase 2: Compose Stack

**Goal:** Define the two-service docker-compose stack with service discovery, health-gated startup, env-var override for host Ollama fallback, and Podman compatibility.

**Requirements:**
- COMPOSE-01: `docker-compose.yml` defines `dev-env` and `ollama` services on an isolated internal bridge network
- COMPOSE-02: Dev-env service resolves Ollama by service hostname (`OLLAMA_HOST` defaults to `http://ollama:11434`)
- COMPOSE-03: `OLLAMA_HOST` env var override allows switching to Windows host Ollama at `10.10.10.10:11434`
- COMPOSE-04: Compose file includes `x-podman` extension block; compatible with both `docker compose` v2 and `podman compose`
- COMPOSE-05: Ollama service health check (`GET /api/tags`) gates `dev-env` startup via `depends_on: condition: service_healthy`

**Success Criteria:**
1. `docker compose up` results in dev-env waiting until Ollama passes its health check before starting
2. AI tools inside dev-env successfully reach `http://ollama:11434` by service name with no additional configuration
3. Setting `OLLAMA_HOST=http://10.10.10.10:11434` before `docker compose up` routes AI traffic to the Windows host Ollama instead
4. `podman compose up` completes without errors using the same compose file

**Notes:** Use an explicitly named bridge network (e.g., `ai-net`) — avoid hyphenated auto-generated names which cause Podman compatibility issues. Place `docker-compose.yml` in `.devcontainer/` so paths resolve correctly from devcontainer.json. Use `internal: false` on the network (allow host access without exposing ports externally). Named volumes for `/root/.ollama` and dev-cache ensure model data persists across container restarts.

---

### Phase 3: Devcontainer Integration

**Goal:** Update `.devcontainer/devcontainer.json` to reference the compose file, set the primary service, workspace folder, remote user, and start both services on VS Code reopen.

**Requirements:**
- DEV-01: `.devcontainer/devcontainer.json` updated to use `dockerComposeFile` pointing to compose file in `.devcontainer/`
- DEV-02: `devcontainer.json` correctly sets `service: dev-env`, `workspaceFolder: /workspace`, `remoteUser: dev`
- DEV-03: `devcontainer.json` starts both `dev-env` and `ollama` via `runServices`

**Success Criteria:**
1. Opening the repo in VS Code and selecting "Reopen in Container" successfully attaches to the dev-env container with both services running
2. The workspace is mounted at `/workspace` inside the container with no path conflicts
3. Pi and OpenCode inside the container successfully complete an AI inference request against the compose-internal Ollama service

**Notes:** `workspaceMount` in devcontainer.json must explicitly match the compose volume target (`/workspace`) to avoid VS Code mount conflicts. Paths in `dockerComposeFile` resolve relative to the `.devcontainer/` directory. The `runServices` array must list both `dev-env` and `ollama` to ensure Ollama starts even if VS Code only attaches to dev-env.

---

### Phase 4: Export Scripts + CUDA Prep

**Goal:** Implement export scripts (bash + PowerShell) that produce a single transport archive with SHA256 checksum, manifest, and CUDA/driver installers bundled; and CUDA prep scripts (bash + PowerShell) that download matching toolkit installers for the target offline machine.

**Requirements:**
- EXPORT-01: `image-export.sh` saves all compose images to a single gzipped tarball with SHA256 checksum
- EXPORT-02: `image-export.ps1` PowerShell equivalent for Windows host export workflow
- EXPORT-03: Export produces `manifest.json` containing image names, tags, digests, checksums, and CUDA installer list
- EXPORT-04: Export script bundles any CUDA/driver installers downloaded by `cuda-prep` into the transport archive
- CUDA-01: `cuda-prep.sh` + `cuda-prep.ps1` accept offline machine's GPU model, driver version, and OS; download matching CUDA toolkit + nvidia-container-toolkit for Linux (WSL2/VM target)
- CUDA-02: `cuda-prep` also downloads the correct Windows NVIDIA driver installer for the specified GPU model
- CUDA-03: Scripts include inline comments with exact commands to run on the offline machine to retrieve required info (GPU model, driver version, kernel version, OS release)

**Success Criteria:**
1. Running `image-export.sh` produces a single `.tar.gz` archive and a matching `SHA256SUMS` file covering both images
2. `manifest.json` inside the archive contains image names, tags, digests, and a list of any CUDA/driver installers bundled
3. Running `cuda-prep.sh` with a GPU model + driver version + OS string downloads CUDA toolkit, nvidia-container-toolkit, and Windows driver installer to a local directory that is then bundled by the export script
4. The PowerShell equivalents (`image-export.ps1`, `cuda-prep.ps1`) produce identical output on a Windows host

**Notes:** CUDA prep scripts must include inline comments documenting the exact commands the end user should run on their offline machine to retrieve GPU model (`nvidia-smi --query-gpu=name --format=csv,noheader`), driver version, kernel version (`uname -r`), and OS release (`lsb_release -rs`). Export should verify Docker/Podman is running before proceeding and fail fast with a clear message if not. The bash and PowerShell scripts should produce identical archive formats so an export from either platform can be imported by either import script.

---

### Phase 5: Import Scripts

**Goal:** Implement import scripts (bash + PowerShell) that verify the transport archive, load images, validate compose syntax, and install CUDA/driver components when present.

**Requirements:**
- IMPORT-01: `image-import.sh` verifies SHA256, loads images via `docker load`, validates compose syntax, reports service status
- IMPORT-02: `image-import.ps1` PowerShell equivalent for Windows host import workflow
- IMPORT-03: If CUDA/driver installers are present in archive, import script installs them; if GPU config exists but no installers found, warns with instructions to re-run `cuda-prep`

**Success Criteria:**
1. Running `image-import.sh` on a machine with no internet and no prior images results in all compose services starting successfully after the script completes
2. SHA256 mismatch causes an immediate abort with a clear error message before any images are loaded
3. When CUDA/driver installers are present in the archive, the import script installs them without requiring user intervention; when absent but GPU config exists, a warning message includes the exact `cuda-prep` command to run

**Notes:** Import must verify Docker (or Podman) is running and the user has appropriate permissions before proceeding. `docker compose config` validation should occur after image load, not before, since the compose file references images that may not exist until after load. WSL2-specific: verify `systemd` is enabled and user is in the `docker` group before attempting to start services.

---

### Phase 6: Workspace Template

**Goal:** Provide a copyable example workspace template (`.devcontainer/` + `docker-compose.yml`) with inline documentation covering the complete air-gap deployment workflow.

**Requirements:**
- TMPL-01: Example workspace template (`.devcontainer/` + `docker-compose.yml`) provided for users to copy into their own project
- TMPL-02: Template includes inline documentation covering the full air-gap deployment workflow (export → transport → import → open in VS Code)

**Success Criteria:**
1. A developer can copy the template directory into a new project, run `docker compose up`, and have both services start without any modification to the template files
2. The inline documentation in the template covers every step from running `cuda-prep` through opening in VS Code, with no gaps requiring external documentation
3. The template works as a standalone reference — all values (image references, network names, environment variables) are clearly labelled and match the production compose file

**Notes:** Template should reference GHCR image tags explicitly (not `latest`) so air-gapped deployments are reproducible. Include both the `OLLAMA_HOST` default (compose-internal) and override (Windows host Ollama) as commented examples. Template is the primary onboarding artifact for new users — inline comments are the documentation; do not rely on a separate README.

---

## Requirement Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| OLLAMA-01 | Phase 1 | Pending |
| OLLAMA-02 | Phase 1 | Pending |
| OLLAMA-03 | Phase 1 | Pending |
| OLLAMA-04 | Phase 1 | Pending |
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
