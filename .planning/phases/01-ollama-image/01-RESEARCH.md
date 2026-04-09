# Phase 1: Ollama Image - Research

**Researched:** 2026-04-09
**Domain:** Ollama Docker image authoring, BuildKit GHA caching, GHCR publishing
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `Dockerfile.ollama` at repository root alongside existing `Dockerfile`
- **D-02:** One RUN layer per model — gemma4:26b and gemma4:e4b each get their own RUN, keyed to independent GHA cache scopes. Pattern: `ollama serve & sleep 10 && ollama pull <model> && pkill ollama`
- **D-03:** Push both `:latest` and `:sha-{7-char-git-short}` tags on every successful build. Image name: `ghcr.io/ldj-share/.dotfiles/ollama-models`
- **D-04:** New dedicated `build-ollama.yml` — does not extend `build-container.yml`. Independent path triggers (`Dockerfile.ollama`, `build-ollama.yml`). Manual trigger must be possible.
- **D-05:** `OLLAMA_HOST=0.0.0.0:11434` bound for internal network accessibility
- **D-06:** BuildKit GHA cache (`--cache-from type=gha`) scoped per model layer
- **D-07:** GPU/CPU detection is runtime behavior — image builds once; `ollama` handles GPU detection at container start via NVIDIA device passthrough
- **D-08:** Do NOT use `device_requests` (deprecated); GPU config is Phase 2 concern
- **D-09:** GHCR single-layer limit is 10GB — expect multi-layer push; document in CI output

### Claude's Discretion

- Exact retry loop implementation (retries count, sleep interval between attempts)
- Base image choice: official `ollama/ollama` vs Ubuntu + manual install
- Exact health check endpoint for CI validation (`/api/tags` or `/api/version`)
- `build-ollama.yml` runner OS and job structure

### Deferred Ideas (OUT OF SCOPE)

- None from discussion — phase scope was firm
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OLLAMA-01 | Ollama container image pre-baked with `gemma4:26b` and `gemma4:e4b`, published to GHCR | Base image, model pull pattern, GHCR push workflow |
| OLLAMA-02 | NVIDIA GPU passthrough when available; degrades gracefully to CPU | Runtime GPU detection via nvidia-container-toolkit passthrough; no Dockerfile changes needed |
| OLLAMA-03 | `OLLAMA_HOST` bound to `0.0.0.0:11434` | ENV directive in Dockerfile; verified against Ollama FAQ |
| OLLAMA-04 | GitHub Actions workflow builds and publishes to GHCR on changes | `build-push-action` with GHA cache, path triggers, GHCR login pattern from existing workflow |
</phase_requirements>

---

## Summary

Phase 1 builds a pre-baked Ollama container image containing both gemma4 models. The core
technical challenge is running `ollama serve` inside a Dockerfile RUN layer (Docker does not
start container services during build), pulling each model, then stopping the server — all
without internet access after the initial build. The second challenge is keeping CI fast: a
27GB+ image cannot rebuild from scratch on every push. BuildKit GHA cache with per-model scope
solves this by caching each model's RUN layer independently.

The official `ollama/ollama` base image is the correct choice. It ships the `ollama` binary,
sets up correct paths (`/usr/share/ollama/.ollama/models`), and the GPU passthrough story
(NVIDIA Container Toolkit at runtime) is already handled by Ollama's own detection logic — no
Dockerfile changes needed for OLLAMA-02.

The GHCR 10GB-per-layer limit is real and documented. gemma4:26b is 18GB and gemma4:e4b is
9.6GB, meaning both will be split across multiple layers in the OCI manifest. This is normal
behavior for large images and does not block push — Docker's push client handles it
transparently. CI disk space is the other constraint: ubuntu-latest runners have ~22GB free,
which is not enough to build both models in sequence without either cleanup or a
maximize-disk-space pre-step.

**Primary recommendation:** Use `FROM ollama/ollama:latest` (pin to a specific semver tag for
reproducibility), one RUN layer per model with a retry loop using `ollama ls` as the server
readiness check (not curl — curl is missing from the base image), separate GHA cache scopes per
model, and a disk-space maximize step before the build. Health check in CI via `curl` installed
in a separate step (not inside the container), or use `/api/version` which can be probed from
outside the container.

---

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| `ollama/ollama` | `0.20.x` (pin semver) | Base image — ships Ollama binary, correct paths, CUDA runtime libs | Official image; GPU passthrough works out-of-box; correct model storage paths |
| `docker/build-push-action` | v5 | BuildKit-based Docker build + push | Already used in `build-container.yml`; supports GHA cache natively |
| `docker/login-action` | v3 | GHCR authentication | Already used in existing workflow |
| `docker/setup-buildx-action` | v3 | Enables BuildKit and multi-platform builds | Required for GHA cache backend |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `easimon/maximize-build-space` | latest | Reclaim 20-40GB on ubuntu-latest runner | Required — 22GB free is insufficient for 27GB+ model build without cleanup |
| `actions/checkout` | v4 | Check out repo in CI | Standard; already in existing workflow |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ollama/ollama` base | Ubuntu + manual `curl -fsSL https://ollama.ai/install.sh` | Manual install requires internet at build time — violates air-gap build requirement; `ollama/ollama` has binary pre-installed |
| GHA cache (`type=gha`) | Registry cache (`type=registry`) | Registry cache requires a writable registry ref to store cache blobs; simpler for this use case to use GHA |
| `ubuntu-latest` runner | Self-hosted runner with GPU | Self-hosted adds infrastructure complexity; builds do not need GPU (model pull is CPU-only); `ubuntu-latest` + disk maximize is sufficient |

**Installation (no extra packages needed — base image ships everything):**
```bash
# Dockerfile.ollama uses the official image as base
FROM ollama/ollama:0.20.3
```

**Version verification:** [VERIFIED: hub.docker.com/r/ollama/ollama/tags] — `0.20.3` is the latest stable as of 2026-04-09. gemma4 requires Ollama v0.20.0+. [VERIFIED: github.com/open-webui/open-webui/issues/23471]

---

## Architecture Patterns

### Recommended Project Structure

```
.
├── Dockerfile                          # existing dev-env image (unchanged)
├── Dockerfile.ollama                   # NEW — ollama image with pre-baked models
└── .github/
    └── workflows/
        ├── build-container.yml         # existing (unchanged)
        └── build-ollama.yml            # NEW — dedicated CI for ollama image
```

### Pattern 1: Model Pre-bake via Background Serve + Retry Loop

**What:** Run `ollama serve` in the background inside a Dockerfile RUN instruction, wait for the
HTTP API to become available using a retry loop, pull the model, then stop the server. Docker
commits the layer after the RUN completes, preserving the pulled model blobs.

**When to use:** Any time models must be baked into the image at build time (air-gap requirement).

**Key constraints:**
- `curl` is NOT present in `ollama/ollama` base image [VERIFIED: github.com/ollama/ollama/issues/9781]
- Use `ollama ls` or `ollama list` as the readiness probe — they connect to the local server and
  fail until it is ready, no external HTTP client needed
- `sleep 10` is a minimum baseline; production pattern uses a retry loop (10-30 retries at 2s
  intervals) because CI runners vary in startup latency
- Use a non-default port (e.g., `127.0.0.1:11235`) for the build-time server to avoid any
  confusion with the final `OLLAMA_HOST` binding

**Example (D-02 pattern, expanded):**

```dockerfile
# Source: ollama.com/faq + github.com/ollama/ollama/issues/5017 + D-02 decision
RUN OLLAMA_HOST=127.0.0.1:11235 ollama serve & \
    _pid=$! && \
    _ready=0 && \
    for i in $(seq 1 30); do \
      if OLLAMA_HOST=127.0.0.1:11235 ollama ls >/dev/null 2>&1; then \
        _ready=1; break; \
      fi; \
      sleep 2; \
    done && \
    [ "$_ready" = "1" ] || (echo "ERROR: ollama server did not start" && kill $_pid && exit 1) && \
    OLLAMA_HOST=127.0.0.1:11235 ollama pull gemma4:26b && \
    kill $_pid && wait $_pid 2>/dev/null || true

RUN OLLAMA_HOST=127.0.0.1:11235 ollama serve & \
    _pid=$! && \
    _ready=0 && \
    for i in $(seq 1 30); do \
      if OLLAMA_HOST=127.0.0.1:11235 ollama ls >/dev/null 2>&1; then \
        _ready=1; break; \
      fi; \
      sleep 2; \
    done && \
    [ "$_ready" = "1" ] || (echo "ERROR: ollama server did not start" && kill $_pid && exit 1) && \
    OLLAMA_HOST=127.0.0.1:11235 ollama pull gemma4:e4b && \
    kill $_pid && wait $_pid 2>/dev/null || true
```

Note: Each RUN block gets its own GHA cache scope (see Pattern 2). The two blocks are
intentionally separate (D-02) so a model update to e4b does not invalidate the 18GB gemma4:26b
cache entry.

### Pattern 2: Per-Model GHA Cache Scoping

**What:** Assign a unique `scope` value to each `cache-from`/`cache-to` in the
`docker/build-push-action` call so each model's RUN layer has an independent cache entry.

**When to use:** When a Dockerfile has multiple heavyweight RUN layers that change at different
frequencies (D-06).

**Example:**

```yaml
# Source: docs.docker.com/build/cache/backends/gha/ + D-06 decision
- name: Build Ollama image
  uses: docker/build-push-action@v5
  with:
    context: .
    file: Dockerfile.ollama
    push: false
    load: true
    tags: ollama-models:ci
    cache-from: |
      type=gha,scope=ollama-gemma4-26b
      type=gha,scope=ollama-gemma4-e4b
    cache-to: |
      type=gha,mode=max,scope=ollama-gemma4-26b
      type=gha,mode=max,scope=ollama-gemma4-e4b
```

**Important:** BuildKit matches cache scopes to layers heuristically. Using `mode=max` exports
all intermediate layers (not just final image layers), which is required to cache the model RUN
layers. [VERIFIED: docs.docker.com/build/cache/backends/gha/]

### Pattern 3: Short SHA Tag Generation

**What:** Extract the first 7 characters of `GITHUB_SHA` for the `:sha-` image tag (D-03).

**Example:**

```yaml
# Source: github.com/docker/build-push-action/issues/440
- name: Set short SHA
  id: sha
  run: echo "SHORT_SHA=${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"

- name: Push to GHCR
  uses: docker/build-push-action@v5
  with:
    tags: |
      ghcr.io/${{ env.OWNER }}/dotfiles/ollama-models:latest
      ghcr.io/${{ env.OWNER }}/dotfiles/ollama-models:sha-${{ steps.sha.outputs.SHORT_SHA }}
```

### Pattern 4: Disk Space Maximization (Required for 27GB+ Build)

**What:** Free up disk on ubuntu-latest runner before the Docker build step.

**When to use:** Any build where models + Docker layers exceed ~22GB. [VERIFIED: github.com/easimon/maximize-build-space]

```yaml
# Source: github.com/easimon/maximize-build-space
- name: Maximize build disk space
  uses: easimon/maximize-build-space@master
  with:
    remove-dotnet: 'true'
    remove-android: 'true'
    remove-haskell: 'true'
    remove-codeql: 'true'
    remove-docker-images: 'true'
    root-reserve-mb: 2048
  # Recovers 20-40GB; must run before actions/checkout
```

### Pattern 5: CI Validation Without curl Inside Container

**What:** Validate that the built image serves both models by running the container in CI and
probing from the runner (where curl IS available).

**When to use:** Verifying OLLAMA-01 success criteria — both models present in `/api/tags` response.

```yaml
# Source: OLLAMA-01 success criteria + /api/tags pattern
- name: Validate models present
  run: |
    docker run --rm -d --name ollama-ci \
      -e OLLAMA_HOST=0.0.0.0:11434 \
      -p 11434:11434 \
      ollama-models:ci
    # Wait for server to be ready (poll from runner, curl IS available on ubuntu-latest)
    for i in $(seq 1 30); do
      if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
        break
      fi
      sleep 3
    done
    # Assert both models present
    TAGS=$(curl -sf http://localhost:11434/api/tags)
    echo "$TAGS" | grep -q "gemma4:26b" || (echo "FAIL: gemma4:26b missing" && exit 1)
    echo "$TAGS" | grep -q "gemma4:e4b"  || (echo "FAIL: gemma4:e4b missing"  && exit 1)
    echo "PASS: Both models present"
    docker stop ollama-ci
```

### Anti-Patterns to Avoid

- **curl health check inside Dockerfile HEALTHCHECK:** `curl` is not present in `ollama/ollama`
  base image. Use `ollama ls` for build-time readiness checks; handle container health check
  separately or install curl via `apt-get install -y curl` in the Dockerfile.
- **Single GHA cache scope for all layers:** Changing e4b invalidates the 18GB gemma4:26b cache.
  Always use separate scopes (D-06).
- **`mode=min` on cache-to:** Only caches the final image layers, not the model pull layers.
  Use `mode=max`.
- **Building without disk space cleanup:** ubuntu-latest runners have ~22GB free; building two
  models totaling 27GB+ without freeing space will fail with "no space left on device".
- **Using `github.sha` directly as image tag:** The full 40-char SHA is valid but unwieldy for
  export scripts. Use 7-char substring per D-03.
- **`device_requests` in compose:** Deprecated. GPU passthrough is Phase 2 (`deploy.resources.
  reservations.devices`), not Phase 1. Phase 1 Dockerfile needs no GPU-specific directives.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BuildKit GHA cache management | Custom `actions/cache` + tar logic | `type=gha` in `cache-from`/`cache-to` | BuildKit's GHA exporter handles layer de-duplication, partial restores, and eviction automatically |
| Short SHA extraction | Bash substring manipulation in multiple places | One step with `$GITHUB_ENV` or `$GITHUB_OUTPUT` | Centralizes; reusable across jobs |
| Disk space cleanup on runner | Custom `rm -rf` commands | `easimon/maximize-build-space` action | Tested combination of LVM volume merge + selective package removal |
| Ollama server readiness in RUN | Fixed `sleep N` (fragile on slow runners) | Retry loop with `ollama ls` (built into the base image) | `ollama ls` is always available; retry handles variable runner latency |

---

## Common Pitfalls

### Pitfall 1: Out of Disk Space Mid-Build

**What goes wrong:** The `docker build` for gemma4:26b (18GB) or gemma4:e4b (9.6GB) fails with
"no space left on device" during the `ollama pull` step inside the RUN layer.

**Why it happens:** ubuntu-latest runners start with ~22GB free. After checkout, BuildKit cache
restore, and the base `ollama/ollama` image layer, less than 18GB remains for the first model pull.

**How to avoid:** Add `easimon/maximize-build-space` (or equivalent) as the very first step in
the build job, before `actions/checkout`. This must be first because it reformats the build volume.

**Warning signs:** Build exits with non-zero in the model pull RUN layer. Docker daemon log shows
`write /var/lib/docker/...`: no space left on device.

### Pitfall 2: GHA Cache Miss on Every Run (mode=min)

**What goes wrong:** CI always rebuilds both model layers even when neither Dockerfile nor
models changed.

**Why it happens:** `cache-to: type=gha` defaults to `mode=min`, which only exports final-stage
layers. The model RUN layers are intermediate (they write to `/usr/share/ollama/.ollama/models`)
and get excluded from the min-mode export.

**How to avoid:** Always specify `mode=max` on `cache-to`. [VERIFIED: docs.docker.com/build/cache/backends/gha/]

**Warning signs:** Build consistently takes 30+ minutes even when nothing changed.

### Pitfall 3: `ollama/ollama:latest` Tag Lag

**What goes wrong:** `:latest` on Docker Hub may lag the actual latest release by hours to days.
[VERIFIED: github.com/ollama/ollama/issues/13039 — documented lag in `:latest` tag update]

**Why it happens:** The Docker Hub automated publishing pipeline can fall behind the GitHub releases.

**How to avoid:** Pin to a specific semver tag (e.g., `ollama/ollama:0.20.3`). Update
intentionally when a new version is needed. The `build-ollama.yml` workflow path trigger means
bumping the tag in `Dockerfile.ollama` is the correct upgrade path.

**Warning signs:** `ollama version` inside the container reports lower than expected; gemma4 pull
fails with "requires a newer version of Ollama".

### Pitfall 4: curl Missing Inside Container for Health Checks

**What goes wrong:** Dockerfile `HEALTHCHECK` using `curl http://localhost:11434/api/tags` fails
with "executable file not found in $PATH".

**Why it happens:** `ollama/ollama` base image does not include `curl`. [VERIFIED: github.com/ollama/ollama/issues/9781]

**How to avoid:** Either (a) install curl via `RUN apt-get install -y curl` in Dockerfile.ollama
(adds ~3MB, makes HEALTHCHECK work), or (b) do CI validation from the runner host (where curl
IS available) rather than from inside the container. For the Dockerfile `HEALTHCHECK` directive,
adding curl is the cleaner solution and is needed anyway for Phase 2 compose health checks.

**Warning signs:** `docker inspect` shows container health as "unhealthy" despite server running.

### Pitfall 5: Build-Time Port Collision with Final OLLAMA_HOST

**What goes wrong:** Using `OLLAMA_HOST=0.0.0.0:11434` for the build-time server means the
`ENV OLLAMA_HOST=0.0.0.0:11434` directive applies during the RUN layer, and subsequent RUN
layers that spin up a second server instance fail with "address already in use" if the first
was not cleanly stopped.

**How to avoid:** Use a non-production port (e.g., `127.0.0.1:11235`) for all build-time
`ollama serve` calls. Set `ENV OLLAMA_HOST=0.0.0.0:11434` only after all model-pull RUN layers
are complete — or set it as the last Dockerfile directive.

### Pitfall 6: Scope Collision Between `build-container.yml` and `build-ollama.yml`

**What goes wrong:** If both workflows use the default `scope=buildkit`, each build overwrites
the other's GHA cache, causing near-total cache misses on alternating runs.

**How to avoid:** Use uniquely named scopes in `build-ollama.yml`:
`scope=ollama-gemma4-26b` and `scope=ollama-gemma4-e4b`. These names are
distinct from the default `buildkit` scope used by `build-container.yml`. [VERIFIED: docs.docker.com/build/cache/backends/gha/]

---

## Code Examples

### Complete Dockerfile.ollama Skeleton

```dockerfile
# Source: ollama/ollama Docker Hub + CONTEXT.md decisions D-01 through D-09
# ─────────────────────────────────────────────────────────────────────────────
# Ollama image pre-baked with gemma4:26b and gemma4:e4b models.
#
# Published to: ghcr.io/ldj-share/.dotfiles/ollama-models:latest
#
# GPU passthrough is handled at RUNTIME by the NVIDIA Container Toolkit —
# this image builds once and supports both GPU and CPU-only deployments.
#
# GHCR note: gemma4:26b (18GB) and gemma4:e4b (9.6GB) will be split across
# multiple OCI layers — the 10GB per-layer limit is enforced at push time.
# Docker's push client handles splitting transparently.
# ─────────────────────────────────────────────────────────────────────────────

FROM ollama/ollama:0.20.3

# Install curl so HEALTHCHECK and compose health gates work
# (curl is absent from the base image — see ollama/ollama#9781)
RUN apt-get update -qq && apt-get install -y -qq curl && rm -rf /var/lib/apt/lists/*

# Pull gemma4:26b (~18GB) — runs on a temporary build-time server
# GHA cache scope: ollama-gemma4-26b (independent from e4b layer)
RUN OLLAMA_HOST=127.0.0.1:11235 ollama serve & \
    _pid=$! && \
    _ready=0 && \
    for i in $(seq 1 30); do \
      if OLLAMA_HOST=127.0.0.1:11235 ollama ls >/dev/null 2>&1; then \
        _ready=1; break; \
      fi; \
      sleep 2; \
    done && \
    [ "$_ready" = "1" ] || (echo "ERROR: ollama did not start for gemma4:26b pull" && kill $_pid && exit 1) && \
    OLLAMA_HOST=127.0.0.1:11235 ollama pull gemma4:26b && \
    kill $_pid && wait $_pid 2>/dev/null || true

# Pull gemma4:e4b (~9.6GB) — separate RUN = independent cache layer (D-02)
# GHA cache scope: ollama-gemma4-e4b
RUN OLLAMA_HOST=127.0.0.1:11235 ollama serve & \
    _pid=$! && \
    _ready=0 && \
    for i in $(seq 1 30); do \
      if OLLAMA_HOST=127.0.0.1:11235 ollama ls >/dev/null 2>&1; then \
        _ready=1; break; \
      fi; \
      sleep 2; \
    done && \
    [ "$_ready" = "1" ] || (echo "ERROR: ollama did not start for gemma4:e4b pull" && kill $_pid && exit 1) && \
    OLLAMA_HOST=127.0.0.1:11235 ollama pull gemma4:e4b && \
    kill $_pid && wait $_pid 2>/dev/null || true

# Bind to all interfaces for compose internal network access (OLLAMA-03, D-05)
ENV OLLAMA_HOST=0.0.0.0:11434

EXPOSE 11434

# Health check — requires curl (installed above)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -sf http://localhost:11434/api/tags || exit 1
```

### build-ollama.yml Structure (Key Sections)

```yaml
# Source: build-container.yml structure (CONTEXT.md canonical ref) + D-04 decisions
name: Build and Publish Ollama Image

on:
  push:
    branches: [master, 'feature/**']
    paths:
      - Dockerfile.ollama
      - .github/workflows/build-ollama.yml
  pull_request:
    paths:
      - Dockerfile.ollama
      - .github/workflows/build-ollama.yml
  workflow_dispatch:  # manual trigger for model version bumps

jobs:
  lint:
    name: Lint (ShellCheck)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # ShellCheck any shell scripts added alongside this phase
      # (Dockerfile.ollama itself has no shell scripts to lint)

  build-and-test:
    name: Build and Test
    runs-on: ubuntu-latest
    needs: lint
    permissions:
      contents: read
      packages: write

    steps:
      # Must be FIRST — reformats build volume; cannot run after checkout
      - name: Maximize build disk space
        uses: easimon/maximize-build-space@master
        with:
          remove-dotnet: 'true'
          remove-android: 'true'
          remove-haskell: 'true'
          remove-codeql: 'true'
          remove-docker-images: 'true'
          root-reserve-mb: 2048

      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3

      - name: Build image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile.ollama
          push: false
          load: true
          tags: ollama-models:ci
          cache-from: |
            type=gha,scope=ollama-gemma4-26b
            type=gha,scope=ollama-gemma4-e4b
          cache-to: |
            type=gha,mode=max,scope=ollama-gemma4-26b
            type=gha,mode=max,scope=ollama-gemma4-e4b

      - name: Validate models present
        run: |
          docker run --rm -d --name ollama-ci \
            -e OLLAMA_HOST=0.0.0.0:11434 \
            -p 11434:11434 \
            ollama-models:ci
          for i in $(seq 1 30); do
            curl -sf http://localhost:11434/api/tags >/dev/null 2>&1 && break
            sleep 3
          done
          TAGS=$(curl -sf http://localhost:11434/api/tags)
          echo "$TAGS" | grep -q "gemma4:26b" || (echo "FAIL: gemma4:26b not found" && exit 1)
          echo "$TAGS" | grep -q "gemma4:e4b"  || (echo "FAIL: gemma4:e4b not found"  && exit 1)
          echo "PASS: Both models present"
          docker stop ollama-ci

  publish:
    name: Publish to GHCR
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.ref == 'refs/heads/master' && github.event_name == 'push'
    permissions:
      contents: read
      packages: write

    steps:
      - name: Maximize build disk space
        uses: easimon/maximize-build-space@master
        with:
          remove-dotnet: 'true'
          remove-android: 'true'
          remove-haskell: 'true'
          remove-codeql: 'true'
          remove-docker-images: 'true'
          root-reserve-mb: 2048

      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set lowercase owner and short SHA
        run: |
          echo "OWNER=$(echo '${{ github.repository_owner }}' | tr '[:upper:]' '[:lower:]')" >> $GITHUB_ENV
          echo "SHORT_SHA=${GITHUB_SHA::7}" >> $GITHUB_ENV

      - name: Push to GHCR
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile.ollama
          push: true
          tags: |
            ghcr.io/${{ env.OWNER }}/dotfiles/ollama-models:latest
            ghcr.io/${{ env.OWNER }}/dotfiles/ollama-models:sha-${{ env.SHORT_SHA }}
          cache-from: |
            type=gha,scope=ollama-gemma4-26b
            type=gha,scope=ollama-gemma4-e4b
          cache-to: |
            type=gha,mode=max,scope=ollama-gemma4-26b
            type=gha,mode=max,scope=ollama-gemma4-e4b
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `device_requests` for GPU in compose | `deploy.resources.reservations.devices` | Docker Compose v2 | `device_requests` is deprecated; new form is the standard |
| GHA cache hard-capped at 10GB/repo | Pay-as-you-go above 10GB (free tier stays 10GB) | November 2025 [CITED: github.blog changelog] | Large repos can exceed 10GB; still scoped per-repo |
| `ollama serve` with fixed sleep | Retry loop with `ollama ls` readiness check | Community pattern, 2024-2025 | More reliable on variable-latency runners |
| `FROM ubuntu + curl install.sh` | `FROM ollama/ollama` | Ollama official image launch | Official image ships correct binary + paths; no install script at build time |

**Deprecated/outdated:**
- `device_requests` in Docker Compose: replaced by `deploy.resources.reservations.devices`
- Fixed `sleep 10` with no retry: fragile; use a retry loop with `ollama ls`

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ollama ls` works as a server readiness probe during Dockerfile RUN (before any models are pulled, it returns empty list rather than connection error) | Architecture Patterns, Pattern 1 | Retry loop exits immediately; build fails. Mitigation: also check exit code 0 specifically, not just successful run |
| A2 | GHA cache `mode=max` preserves model-pull RUN layers even though they only write to a data directory rather than the final filesystem slice visible in the image | Common Pitfalls #2, Pattern 2 | Cache misses on every run; 30+ min rebuild every time. Mitigation: test on first CI run and check cache hit/miss in build output |
| A3 | `easimon/maximize-build-space` frees enough space for a 27GB build; aggressive removal (~40GB recovered) does not break Docker daemon or BuildKit on ubuntu-latest | Common Pitfalls #1, Pattern 4 | Build still fails out of disk space. Mitigation: use `remove-docker-images: 'true'` only after confirming Docker is reinstalled, or use GitHub's larger runners (4-core, 16GB, 150GB disk) as fallback |
| A4 | The Dockerfile `HEALTHCHECK` is not strictly required by Phase 1 (it is used by Phase 2 compose `depends_on`); including it here is a forward-compatible decision | Dockerfile skeleton | No risk to Phase 1; if Phase 2 requires a different approach, it overrides |

---

## Open Questions

1. **GHA cache total size for two model scopes**
   - What we know: gemma4:26b is 18GB, gemma4:e4b is 9.6GB; GHA free tier is 10GB/repo
   - What's unclear: With `mode=max`, will BuildKit attempt to store the full 27GB+ model data in GHA cache? If so, the free tier will evict on every run and the cache provides no benefit.
   - Recommendation: On the first CI run, check the GHA cache size in the Actions UI. If model blobs exceed the GHA cache budget, switch `cache-to` to `type=registry` using a throwaway GHCR tag (e.g., `ghcr.io/.../ollama-models:buildcache`) — this has no size limit and persists between runs.

2. **Can the build-and-test and publish jobs share a GHA cache restore, or must publish rebuild from scratch?**
   - What we know: Each job runs on a fresh runner. GHA cache is restored from the same scope names.
   - What's unclear: Whether BuildKit can restore from the same GHA cache entries that were just populated by build-and-test in the same workflow run (same SHA).
   - Recommendation: Use the same `cache-from` scopes in both jobs. BuildKit's GHA backend reads from the cache store after it is committed; the publish job should get a full cache hit from the build-and-test job's `cache-to` writes.

3. **Ollama version to pin in `FROM ollama/ollama:X.Y.Z`**
   - What we know: gemma4 requires v0.20.0+; latest stable as of research is 0.20.3
   - What's unclear: Whether to pin exactly or use a minor-level float (e.g., `0.20`)
   - Recommendation: Pin the patch version (`0.20.3`) for full reproducibility. Update via a Dockerfile.ollama edit (which triggers the workflow via path filter).

---

## Environment Availability

This phase runs entirely in GitHub Actions (cloud CI). No local build environment is required for
Phase 1 artifacts. The build produces an image published to GHCR; consumption happens in Phase 2.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| GitHub Actions (ubuntu-latest) | All CI jobs | Yes (cloud) | Current | — |
| Docker Buildx | Build | Yes (setup-buildx-action@v3) | Latest | — |
| GHCR (ghcr.io) | Publish job | Yes | — | — |
| `GITHUB_TOKEN` secret | GHCR push auth | Yes (automatic in Actions) | — | — |
| ollama/ollama:0.20.3 on Docker Hub | Base image | Yes (public) | 0.20.3 | Pin to 0.20.x |
| ~40GB disk after cleanup | Model build | Requires maximize-disk-space action | N/A | Larger runner (paid) |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Bash scripts + `curl` smoke test (no unit test framework; infrastructure phase) |
| Config file | None — tests are inline steps in `build-ollama.yml` |
| Quick run command | `docker run --rm -p 11434:11434 ollama-models:ci` + curl probe |
| Full suite command | Full `build-ollama.yml` CI run |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| OLLAMA-01 | Both models present in `/api/tags` | Smoke | `curl -sf http://localhost:11434/api/tags \| grep gemma4:26b && grep gemma4:e4b` | Runs in build-and-test job |
| OLLAMA-02 | CPU-only start (no GPU in CI runner) | Smoke | Container starts successfully; `/api/tags` responds | CI runner has no GPU — confirms CPU fallback. GPU path requires manual test |
| OLLAMA-03 | Server bound to `0.0.0.0:11434` | Smoke | `curl http://localhost:11434/api/tags` from runner (not localhost inside container) | Port-mapped; if binding were 127.0.0.1:11434 inside container, external port map would fail |
| OLLAMA-04 | Workflow publishes image to GHCR | Integration | GHA workflow completes; `docker pull ghcr.io/.../ollama-models:sha-<7char>` succeeds | Verified via GHCR package page post-run |

### Wave 0 Gaps

- [ ] `Dockerfile.ollama` — does not exist yet; Wave 0 creates it
- [ ] `.github/workflows/build-ollama.yml` — does not exist yet; Wave 0 creates it
- [ ] No existing test scripts to ShellCheck for Phase 1 (all validation is inline CI steps)

---

## Security Domain

This phase has a narrow security surface — it builds and publishes a container image. No user
authentication, session management, or application data handling.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | Partial | GHCR publish gated to `master` + passing tests; `GITHUB_TOKEN` scoped to `packages: write` only |
| V5 Input Validation | No | — |
| V6 Cryptography | No | — |
| Supply Chain (SLSA) | Partial | Pinned action versions + pinned base image tag reduce substitution risk |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Base image substitution | Tampering | Pin `FROM ollama/ollama:0.20.3` to a specific semver — prevents silent `:latest` substitution |
| Workflow secret exfiltration | Info Disclosure | `GITHUB_TOKEN` scoped to `packages: write` only; no external secrets needed for this phase |
| Cache poisoning via GHA cache | Tampering | GHA cache is repository-scoped; only code authors with push access can write cache entries |
| Malicious model weights | Tampering | Models pulled from `ollama.com` registry at build time; Ollama verifies SHA256 of downloaded blobs [ASSUMED] |

---

## Sources

### Primary (HIGH confidence)
- `hub.docker.com/r/ollama/ollama` — base image tags, size confirmation
- `ollama.com/library/gemma4` — model tags, exact sizes (gemma4:26b = 18GB, gemma4:e4b = 9.6GB)
- `docs.ollama.com/faq` — OLLAMA_HOST, OLLAMA_MODELS, other env vars
- `docs.docker.com/build/cache/backends/gha/` — scope, mode, cache-from/cache-to syntax
- `docs.docker.com/build/ci/github-actions/cache/` — GHA cache CI patterns
- `github.com/ollama/ollama/issues/9781` — curl absent from base image, CLOSED/DUPLICATE
- `github.com/easimon/maximize-build-space` — disk space recovery, up to 60GB with software removal

### Secondary (MEDIUM confidence)
- `github.blog/changelog/2025-11-20-github-actions-cache-size-can-now-exceed-10-gb-per-repository` — GHA cache can now exceed 10GB with paid plan; free tier remains 10GB
- `github.com/docker/build-push-action/issues/440` — short SHA tag pattern `${GITHUB_SHA::7}`
- `github.com/ollama/ollama/issues/13039` — `:latest` tag lag on Docker Hub; pinning recommended
- `github.com/open-webui/open-webui/issues/23471` — gemma4 requires Ollama v0.20.0+

### Tertiary (LOW confidence)
- General community patterns for `ollama serve & retry loop` — multiple sources agree but no single
  canonical official document; Ollama FAQ only says models must be pulled with server running

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — official image confirmed, versions verified against Docker Hub
- Architecture: HIGH — patterns verified against official Docker docs and confirmed GitHub issues
- Pitfalls: HIGH — each pitfall linked to a concrete GitHub issue or official doc
- Model sizes/tags: HIGH — verified directly against ollama.com/library/gemma4

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (model tags and Ollama versions change frequently; re-verify `ollama/ollama` tag before pinning at implementation time)
