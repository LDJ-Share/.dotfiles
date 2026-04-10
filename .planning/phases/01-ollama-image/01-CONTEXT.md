# Phase 1: Ollama Image - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Build and publish a pre-baked Ollama container image containing gemma4:26b and gemma4:e4b models, with GPU/CPU runtime detection, published to GHCR via a dedicated CI workflow. Does not include the compose stack or devcontainer integration — those are Phase 2 and 3.

</domain>

<decisions>
## Implementation Decisions

### Dockerfile location
- **D-01:** `Dockerfile.ollama` at repository root alongside existing `Dockerfile` (dev-env)
- Standard Docker multi-file convention; CI references as `-f Dockerfile.ollama`

### Model layer strategy
- **D-02:** One RUN layer per model — gemma4:26b and gemma4:e4b each get their own RUN
- BuildKit GHA cache keyed per layer; a change to e4b does not invalidate the ~17GB gemma4:26b cache layer
- Each RUN follows the pattern: `ollama serve & sleep 10 && ollama pull <model> && pkill ollama`
- The `ollama serve` + retry pattern is already decided in ROADMAP.md notes — implement as written

### Image tagging
- **D-03:** Push both `:latest` and `:sha-{7-char-git-short}` tags on every successful build
- `:sha-` tags enable reproducible air-gap exports (export scripts can pin to a specific build)
- Image name: `ghcr.io/ldj-share/.dotfiles/ollama-models`

### CI workflow structure
- **D-04:** New dedicated `build-ollama.yml` workflow — does not extend existing `build-container.yml`
- Independent path triggers: only rebuilds when `Dockerfile.ollama` or `build-ollama.yml` changes
- Easier to trigger manually when model versions are updated

### Locked from ROADMAP.md
- **D-05:** `OLLAMA_HOST=0.0.0.0:11434` — bound for internal network accessibility (OLLAMA-03)
- **D-06:** BuildKit GHA cache (`--cache-from type=gha`) scoped per model layer to avoid 30+ min full rebuilds
- **D-07:** GPU/CPU detection is runtime behavior — the image builds once; `ollama` handles GPU detection at container start via NVIDIA device passthrough
- **D-08:** Do not use `device_requests` (deprecated); GPU config handled in compose via `deploy.resources.reservations.devices` (Phase 2)
- **D-09:** GHCR single-layer limit is 10GB — expect multi-layer push behavior; document in CI output

### Claude's Discretion
- Exact retry loop implementation (how many retries, sleep interval between attempts)
- Base image choice for Dockerfile.ollama (official `ollama/ollama` vs Ubuntu + manual install)
- Exact health check endpoint for CI validation (`/api/tags` or `/api/version`)
- `build-ollama.yml` runner OS and job structure

</decisions>

<specifics>
## Specific Ideas

- No specific aesthetic or behavioral references — this is infrastructure
- The retry loop approach is explicitly noted in ROADMAP.md: `ollama serve & sleep 10` inside the RUN layer before model pulls

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Ollama Container — OLLAMA-01 through OLLAMA-04 define all acceptance criteria
- `.planning/ROADMAP.md` §Phase 1: Ollama Image — Notes section contains implementation constraints (cache strategy, layer limit, serve pattern)

### Existing CI pattern to follow
- `.github/workflows/build-container.yml` — Existing dev-env workflow; Ollama workflow should follow the same structure (lint → build → test → publish jobs)

### No external specs
- No ADRs or design docs for this phase — requirements are fully captured in decisions above and REQUIREMENTS.md

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/build-container.yml`: Full working example of multi-job CI workflow with ShellCheck lint, Docker Buildx build, GHCR publish, and path-scoped triggers — use as structural template for `build-ollama.yml`
- `.devcontainer/devcontainer.json`: Current devcontainer uses `ghcr.io/ldj-share/.dotfiles/dev-env:latest` image reference — shows the GHCR naming convention in use

### Established Patterns
- Existing `Dockerfile` uses multi-stage build with parallel builder stages — Ollama Dockerfile is simpler (single stage, no multi-stage needed) but CI structure is the same
- GitHub Actions workflow triggers on push to `master` and `feature/**` with path filters — same pattern for `build-ollama.yml`

### Integration Points
- Phase 2 (Compose Stack) will reference the Ollama image by its GHCR tag in `docker-compose.yml`
- Export scripts (Phase 4) will save this image by digest/tag — the `:sha-` tagging decision directly enables reproducible exports

</code_context>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-ollama-image*
*Context gathered: 2026-04-09*
