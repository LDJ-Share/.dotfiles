# Pitfalls Research

**Domain:** Pre-baked Ollama Docker + air-gap compose deployment
**Researched:** 2026-04-08
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Ollama Server Not Running During Docker Build RUN Layer

**What goes wrong:**
`RUN ollama pull <model>` during build fails silently or times out. Even if you run `ollama serve &` in background, by the time the next RUN instruction executes, the service is gone. Models don't actually get baked into the image despite the build appearing to succeed.

**Why it happens:**
Each RUN instruction executes in a temporary container that is discarded immediately after the command completes. Background processes started with `&` die when the RUN layer finishes. The Ollama daemon needs several seconds to start and be ready for pull requests.

**How to avoid:**
- Use `ollama serve & sleep 10` to give the daemon time to start before pulling
- Add explicit health check with retry: `until ollama list 2>/dev/null; do sleep 1; done`
- Verify models are present in the same RUN layer before it exits: `ollama list | grep -q <model>`

**Warning signs:**
- Build log shows pull succeeded but `docker run ... ollama list` shows empty
- Runtime container starts but models unavailable until manual `ollama pull`
- Inconsistent behavior between build environments

**Phase to address:** Ollama Container Build

---

### Pitfall 2: Layer Size Explosion with Large Pre-Baked Models

**What goes wrong:**
Final Docker image becomes 20GB+ for gemma4:26b + gemma4:e4b. Push to GHCR fails because file exceeds 10GB single-layer limit. Build cache is busted repeatedly, requiring 20GB+ re-download on every build.

**Why it happens:**
Each model layer is added as a new Docker layer. Models are immutable large blobs (26B + 4B params ≈ 30GB+ serialized). GHCR registry has per-file size limit of 10GB; a combined monolithic image exceeds this. Baking models into the image means every CI/CD rebuild re-downloads 30GB.

**How to avoid:**
- Keep each model in its own RUN layer to maximize Docker layer caching
- Use `--cache-from type=gha` in GitHub Actions to avoid re-pulling unchanged model layers
- Export as tarball for air-gap transport; push only pre-baked image to GHCR (the model layers are just blobs — GHCR handles large layers as long as each push layer is under 10GB)
- Document expected image size (~22GB for both models) upfront

**Warning signs:**
- `docker push` hangs or times out
- GHCR shows image as incomplete or missing layers
- WSL2 disk full errors during build

**Phase to address:** Ollama Container Build + CI/CD

---

### Pitfall 3: Podman Compatibility — Network Naming & Pod Behavior

**What goes wrong:**
docker-compose file works with Docker but services can't reach each other by hostname under Podman. Network names with hyphens behave differently. `device_requests` GPU syntax is unsupported.

**Why it happens:**
Podman Compose puts all services in a single pod by default (shared network namespace), while Docker Compose creates a bridge network with DNS. `device_requests` is a Docker-specific extension not supported by Podman; Podman uses `devices:` or `security_opt:`.

**How to avoid:**
- Use explicit named network: `networks: { ai-net: { name: "ai-net" } }` — avoid relying on compose-generated names
- Test both `docker compose up` and `podman compose up` in CI/CD
- For GPU: use `deploy.resources.reservations.devices` (docker) with a `x-podman` extension block for Podman compatibility
- Avoid `device_requests` entirely; use `deploy: resources` with `capabilities: [gpu]`

**Warning signs:**
- `podman compose up` succeeds but `curl http://ollama:11434` times out from dev-env service
- Different `docker network ls` output between docker and podman

**Phase to address:** Compose Integration + Podman Testing

---

### Pitfall 4: VS Code Devcontainer + docker-compose Workspace Mount Conflicts

**What goes wrong:**
VS Code can't find workspace after `devcontainer.json` specifies `dockerComposeFile`. Container starts but workspace directory is empty. `workspaceMount` conflicts with compose-defined volumes.

**Why it happens:**
VS Code resolves `dockerComposeFile` paths relative to `.devcontainer/` directory, not workspace root. If devcontainer.json specifies a workspace but compose file doesn't mount it, VS Code silently skips the mount.

**How to avoid:**
- Explicitly define: `"workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached"`
- Ensure `workspaceFolder` in devcontainer.json matches the target mount path
- Use a single well-ordered `dockerComposeFile` (avoid arrays unless necessary)
- Test with `devcontainer open` CLI before committing

**Warning signs:**
- Container starts but `ls /workspace` is empty
- VS Code terminal working directory is wrong
- Local files not visible inside container

**Phase to address:** devcontainer Integration

---

### Pitfall 5: WSL2 Docker Socket Permissions & Systemd Startup

**What goes wrong:**
Docker commands fail with "permission denied" on the docker socket. Docker daemon doesn't start automatically when WSL2 boots.

**Why it happens:**
WSL2 doesn't have systemd by default in older versions. User must be in the `docker` group. Group membership changes require WSL2 restart.

**How to avoid:**
- Ensure import instructions include: `sudo usermod -aG docker $(whoami)` then WSL2 restart
- Verify systemd is enabled: `wsl.conf` must have `[boot] systemd=true`
- Verify socket: `ls -la /var/run/docker.sock` should show `docker` group with `rw`
- Import scripts should check Docker is running before proceeding

**Warning signs:**
- `docker ps` returns "permission denied"
- Docker works after `sudo` but not without
- Docker not running after WSL2 restart

**Phase to address:** Import Workflow Scripts

---

### Pitfall 6: Air-Gap Export/Import — Multi-Image Tarball Gotchas

**What goes wrong:**
`docker save` exports only the specified image, missing intermediate layer dependencies. Tarball import fails with "layer not found" on the target machine. Image names/tags are lost during export/import.

**Why it happens:**
`docker save <image>` saves only that image's layers. If the base image isn't included in `docker save`, import succeeds but `docker run` fails at layer resolution. WSL2 path handling (`C:\` vs `/mnt/c/`) causes silent failures.

**How to avoid:**
- Save all images in a single command: `docker save dev-env:latest ollama-models:latest > images.tar`
- Or use separate tarballs per image with verification checksums
- Always use WSL2 paths (`/mnt/c/...`) not Windows paths in import scripts
- Verify after load: `docker images | grep -E "dev-env|ollama-models"`
- Include a `verify.sh` step in import scripts

**Warning signs:**
- `docker run` fails with "image not found" after loading tarball
- `docker load` completes but `docker images` is empty
- "layer not found" errors during `docker run`

**Phase to address:** Export/Import Scripts

---

### Pitfall 7: Large Docker Layer Push Timeouts to GHCR

**What goes wrong:**
`docker push` to GHCR hangs for hours or fails mid-push for 20GB+ images. No resume capability if connection drops.

**Why it happens:**
Large model layers are each a separate blob. 26B model layers can be 15GB+ as a single blob. No push resume built into the Docker CLI.

**How to avoid:**
- Use `--push` with buildx and `--cache-to type=gha,mode=max` to reuse cached layers
- Set GitHub Actions `timeout-minutes: 120` for push jobs
- Consider splitting into `dev-env` image (fast, ~3GB) and `ollama-models` image (slow, ~20GB) with separate workflows triggered by separate path changes

**Warning signs:**
- `docker push` command hangs with no progress for >30 minutes
- GitHub Actions job times out

**Phase to address:** CI/CD Workflow

---

### Pitfall 8: GPU Passthrough — deploy.resources vs nvidia-container-toolkit

**What goes wrong:**
`deploy.resources.reservations.devices` syntax is correct but GPUs not accessible inside container. No error is thrown; Ollama silently falls back to CPU.

**Why it happens:**
`deploy.resources.reservations.devices` requires NVIDIA Container Runtime to be configured on the host. If NVIDIA Container Toolkit isn't installed, the GPU config is ignored without error.

**How to avoid:**
- Verify NVIDIA Container Toolkit: `which nvidia-container-runtime` on the host
- Use correct compose syntax: `capabilities: [gpu]` under `devices:`
- In compose, use this pattern:
  ```yaml
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
  ```
- For Podman: add `x-podman` extension or use `devices: [/dev/nvidia0]`
- Document: if toolkit isn't present, Ollama will use CPU — functional but slow

**Warning signs:**
- `nvidia-smi` inside Ollama container shows "no GPU detected"
- Inference is unexpectedly slow
- `ollama ps` shows CPU instead of GPU

**Phase to address:** Compose File + Documentation

---

### Pitfall 9: Build Cache Busting with Model Downloads

**What goes wrong:**
Every CI/CD run re-downloads 30GB of model files from Ollama hub. Build takes 30+ minutes even for trivial changes.

**Why it happens:**
`RUN ollama pull` is not cached between builds unless the exact RUN instruction is unchanged AND the previous layer hash matches. GitHub Actions ephemeral runners don't have persistent Docker layer cache by default.

**How to avoid:**
- Configure BuildKit cache: `--cache-from type=gha,scope=ollama-models --cache-to type=gha,scope=ollama-models,mode=max`
- Separate the `Dockerfile.ollama` from other Dockerfiles so model layers only rebuild when the model list changes
- Pin the Ollama base image version so the cache key is stable

**Warning signs:**
- Every build takes ~30 minutes even if only a non-model file changed
- `--progress=plain` shows "RUN ollama pull ..." not using cache

**Phase to address:** CI/CD Workflow

---

### Pitfall 10: devcontainer.json Path Resolution for docker-compose

**What goes wrong:**
`dockerComposeFile` path in devcontainer.json doesn't resolve correctly. VS Code opens with default image instead of compose stack.

**Why it happens:**
VS Code resolves `dockerComposeFile` relative to `.devcontainer/`. A compose file at repo root needs path `../docker-compose.yml` — and the path must actually exist at that relative location.

**How to avoid:**
- Place `docker-compose.yml` inside `.devcontainer/` to avoid path confusion, OR
- Use explicit relative path: `"dockerComposeFile": ["../docker-compose.yml"]`
- Always test with `devcontainer open` CLI after changing `devcontainer.json`
- Document the exact file layout users must follow

**Warning signs:**
- VS Code opens in a plain Ubuntu container instead of the compose stack
- "Error opening devcontainer: file not found" on compose file

**Phase to address:** devcontainer Integration

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `2>/dev/null \|\| true` on init steps | Build doesn't fail on non-critical errors | Silent failures; broken image ships | Never for critical tools (nvim, pi, opencode) |
| Hardcoded `10.10.10.10` across 6 files | Simple to read | Single architecture change breaks everything | Never — use env var |
| `latest` tags for base images | Always newest features | Non-reproducible builds, silent breaking changes | Only in dev; pin for published images |
| Single monolithic compose file | Simple to get started | Hard to support both GPU and CPU configs | Acceptable if GPU/CPU handled via env var profile |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Ollama in Docker build | `RUN ollama pull` without starting server first | Start server in same RUN layer with health-check loop |
| Compose service discovery | Using `localhost` to reach Ollama from dev-env | Use service name: `http://ollama:11434` |
| WSL2 paths in scripts | Windows paths (`C:\Users\...`) in bash scripts | WSL paths (`/mnt/c/Users/...`) |
| docker-compose GPU | Missing `capabilities: [gpu]` | Always include under `devices:` |
| Image save for air-gap | Saving only one image | Save ALL compose images in single command |

## "Looks Done But Isn't" Checklist

- [ ] **Models baked in:** `docker run --rm ghcr.io/.../ollama-models ollama list` shows both models
- [ ] **Compose network works:** `docker compose exec dev-env curl http://ollama:11434/api/tags` returns JSON
- [ ] **Podman compat:** `podman compose up` works; services reach each other
- [ ] **GPU config correct:** `docker compose exec ollama nvidia-smi` shows GPU (if toolkit present)
- [ ] **Tarball complete:** Import on clean machine loads both images with correct tags
- [ ] **VS Code devcontainer:** "Reopen in Dev Container" opens with `/workspace` populated
- [ ] **Pi/OpenCode work:** `pi --help` and `opencode --help` run inside dev-env with Ollama reachable
- [ ] **Host fallback:** Setting `OLLAMA_HOST=10.10.10.10:11434` overrides compose service and connects to host Ollama

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Severity | Verification |
|---------|------------------|----------|--------------|
| Ollama server not running in build | Ollama Container Build | CRITICAL | `docker run ollama list` |
| Layer size explosion | Ollama Container Build | CRITICAL | Check GHCR push succeeds |
| Podman network incompatibility | Compose Integration | HIGH | `podman compose up` test |
| devcontainer workspace mount | devcontainer Integration | HIGH | `/workspace` populated in VS Code |
| WSL2 socket permissions | Import Scripts | HIGH | `docker ps` without sudo |
| Air-gap tarball gotchas | Export/Import Scripts | HIGH | Clean-machine import test |
| GHCR push timeout | CI/CD Workflow | MEDIUM | Actions job completes in <120m |
| GPU passthrough config | Compose File | MEDIUM | `nvidia-smi` inside container |
| Build cache busting | CI/CD Workflow | MEDIUM | Second build uses cache |
| devcontainer path resolution | devcontainer Integration | MEDIUM | `devcontainer open` test |

## Sources

- Docker Compose GPU support docs — `deploy.resources.reservations.devices` syntax
- Podman Compose Extensions docs — `x-podman` compatibility block
- VS Code Remote Development — `dockerComposeFile`, `workspaceMount` reference
- GHCR docs — layer size limits
- Ollama Docker Hub — base image entrypoint, port, volume conventions
- Existing codebase CONCERNS.md — known risks in current build
- Existing Dockerfile — current multi-stage build patterns to extend

---
*Pitfalls research for: Pre-baked Ollama Docker + air-gap compose deployment*
*Researched: 2026-04-08*
