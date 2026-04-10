# Research Summary

**Project:** Air-Gapped AI Dev Environment — Compose-First Deployment
**Researched:** 2026-04-08

## Recommended Stack (Top 5)

| Technology | Version | Role |
|------------|---------|------|
| Docker | 24.x+ | Container runtime with native compose integration |
| Docker Compose | v2 | Orchestrate dev-env + ollama services on internal bridge network |
| Ollama | latest | LLM inference via REST API (port 11434, pre-baked models) |
| Ubuntu | 24.04 LTS | Base image for dev container and Ollama service |
| NVIDIA Container Toolkit | 1.x+ | GPU passthrough (optional, graceful CPU fallback) |

---

## Architecture Decision

Use a **two-service docker-compose stack** (dev-env + ollama) on an isolated bridge network with service discovery via Docker DNS. Place docker-compose.yml in .devcontainer/ directory. VS Code devcontainer.json references the compose file, establishing dev-env as the primary service with Ollama as a dependent sidecar. Environment variable OLLAMA_HOST=http://ollama:11434 enables internal service discovery; support OLLAMA_HOST override for host-based Ollama fallback on Windows. Pre-bake models during Docker image build using health-check retry loops to ensure daemon readiness before pull operations.

---

## Table Stakes Features (Must Have)

- Pre-baked Gemma4 models (26b + e4b) baked into Ollama image layer at build time
- docker-compose.yml with service discovery via internal bridge network (no host port exposures)
- Health check on Ollama (GET /api/tags) blocking dev container startup
- VS Code devcontainer.json with dockerComposeFile, service, workspaceFolder, remoteUser fields
- Named volumes for Ollama model persistence (/root/.ollama) and dev-cache
- GPU optional pattern via deploy.resources.reservations.devices (count OR device_ids, not both)
- Air-gap export/import scripts (image-export.sh/ps1 + image-import.sh/ps1) with SHA256 verification
- Single combined tar.gz for both images (dev-env + ollama-models) with gzip compression
- Compose config validation and service health checking in import workflow
- GPU detection (informational only, non-blocking) with fallback to CPU

---

## Top 5 Pitfalls to Avoid

1. **Ollama Server Not Running During Docker Build** — Use `ollama serve & sleep 10` with health-check retry loop before model pulls; verify models present in same RUN layer.
2. **Layer Size Explosion (20GB+ images)** — Separate model layers, use GitHub Actions BuildKit cache (--cache-from type=gha), document expected 22GB final size.
3. **Podman Compatibility — Network Naming & Pod Behavior** — Use explicit named network (ai-net, not hyphenated defaults), test both docker/podman compose in CI/CD, use deploy.resources (not device_requests).
4. **VS Code Workspace Mount Conflicts** — Explicitly define workspaceMount in devcontainer.json matching compose volume target (/workspace), place docker-compose.yml in .devcontainer/.
5. **WSL2 Docker Socket Permissions** — Ensure systemd enabled (wsl.conf), user in docker group, socket has rw perms; scripts must verify Docker running before proceeding.

---

## Key Constraints Confirmed

- Air-gap deployment requires pre-cached images (no runtime registry pulls)
- Models (26B + 4B params ≈ 30GB) must be baked into image, not downloaded at runtime
- GHCR single-layer size limit is 10GB; split images or document as multi-layer
- Windows host cannot directly access container services; use internal service names (ollama:11434)
- Podman requires explicit network naming and x-podman extension block for compatibility
- devcontainer.json paths resolve relative to .devcontainer/ directory
- GPU optional but requires NVIDIA Container Toolkit on host; CPU fallback is silent
- Build cache busting with large models (30+ min rebuilds); mitigate with GitHub Actions GHA cache scope

---

## Recommended Build Order

1. **Ollama Container Build** — Create pre-baked Ollama image with models cached in /root/.ollama layer
2. **Dev Container Build** — Build dev-env image with tooling (Neovim, Pi, OpenCode)
3. **Compose Integration** — Define docker-compose.yml with service discovery, volumes, health checks
4. **devcontainer Integration** — Create devcontainer.json linking to compose file
5. **Export/Import Scripts** — Implement image-export.sh/ps1 + image-import.sh/ps1 with verification
6. **Podman Compatibility** — Add x-podman extension block, test with podman-compose
7. **CI/CD Workflow** — Set up GitHub Actions with BuildKit cache, timeout handling for large pushes

---

## Critical Decisions

| Decision | Recommendation | Confidence |
|----------|----------------|------------|
| Single vs Per-Image Tarball | Single combined tar.gz (atomic, gzip deduplicates layers) | HIGH |
| Volume Strategy for Models | Named volume (native Docker speed, portable, survives deletion) | HIGH |
| GPU Configuration | deploy.resources.reservations.devices with graceful CPU fallback | HIGH |
| Service Discovery | Environment variable OLLAMA_HOST + support override for host Ollama | HIGH |
| Compose File Location | .devcontainer/docker-compose.yml (co-located with devcontainer.json) | HIGH |
| Model Pre-Baking | Build-time with health-check retry (not runtime pulls) | HIGH |
| Podman Support | x-podman extension block (in_pod: false, explicit network names) | MEDIUM |
| Import Validation | SHA256 checksum + docker compose config validation + health checks | HIGH |
| Network Isolation | Bridge network with internal: false (allow host access but not expose) | HIGH |
| Build Cache Strategy | GitHub Actions GHA cache scope per model layer to avoid 30+ min rebuilds | HIGH |

---

**Last Updated:** 2026-04-08
**Source Documents:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md
**Confidence Level:** HIGH (2026 research, official Docker/Ollama/VS Code documentation)
