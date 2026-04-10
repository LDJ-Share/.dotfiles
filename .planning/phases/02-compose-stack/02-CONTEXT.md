# Phase 2: Compose Stack - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Define the two-service compose stack for `dev-env` and `ollama`, with service discovery, health-gated startup, Podman compatibility, and a host-Ollama fallback override. This phase does not switch `.devcontainer/devcontainer.json` to compose mode yet; that is Phase 3.

</domain>

<decisions>
## Implementation Decisions

### AI endpoint strategy
- **D-01:** Compose-first default. Inside the containerized stack, Ollama resolves as `http://ollama:11434`.
- **D-02:** The Windows host address remains an explicit fallback only, enabled by setting `OLLAMA_HOST` before `docker compose up`.

### Compose image references
- **D-03:** Compose uses environment-driven image references with sensible defaults instead of hard-coded tags.
- `DEV_ENV_IMAGE` defaults to `ghcr.io/ldj-share/.dotfiles/dev-env:latest`.
- `OLLAMA_IMAGE` defaults to `ghcr.io/ldj-share/.dotfiles/ollama-models:latest`.

### Persistence layout
- **D-04:** Keep persistence minimal but practical. Persist Ollama model data and the main dev cache volume only.
- Named volumes are sufficient for Phase 2; broader home-directory persistence is deferred.

### Network and visibility
- **D-05:** Ollama stays internal-only by default in compose mode; no host port exposure in the base compose file.
- **D-06:** Use an explicitly named bridge network `ai-net` with `x-podman` metadata for Podman compatibility.

### Startup behavior
- **D-07:** `dev-env` waits for `ollama` health via `depends_on: condition: service_healthy`.
- **D-08:** Because Pi and OpenCode configs are currently file-based, compose startup must rewrite their Ollama endpoint to match `OLLAMA_HOST` so the fallback override is real, not just documented.

### OpenCode's Discretion
- Exact cache volume path choices inside the dev container, as long as persistence stays minimal.
- Whether optional GPU support ships as a separate compose override file or stays documented for later phases.

</decisions>

<specifics>
## Specific Ideas

- Default stack behavior should feel boring and reliable: `docker compose up` starts both services and the AI tools already point at the compose-internal Ollama hostname.
- Host-Ollama fallback must not require redesign later; image references and endpoint handling should already be override-friendly.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Compose — COMPOSE-01 through COMPOSE-05 define the phase acceptance criteria.
- `.planning/ROADMAP.md` §Phase 2: Compose Stack — location, network naming, Podman notes, and success criteria.

### Existing code and prior decisions
- `.planning/STATE.md` — Phase 1 block note and the decision that Phase 2 may proceed using manual model pull fallback.
- `.planning/phases/01-ollama-image/01-CONTEXT.md` — locked Phase 1 decisions, especially runtime GPU handling and the published Ollama image naming.
- `.devcontainer/devcontainer.json` — current non-compose baseline for workspace folder and remote user.

### Current integration points
- `dot-pi/models.json` — Pi currently hard-codes the Windows host Ollama URL.
- `dot-opencode/config.json` — OpenCode currently hard-codes the Windows host Ollama URL.
- `tests/container/test_configs.sh`, `tests/container/test_pi.sh`, `tests/container/test_opencode.sh` — current config expectations that will need to follow the new compose-first default.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Dockerfile` already stows `dot-pi` and `dot-opencode` config into the image, so endpoint defaults can be updated in one place.
- `Dockerfile.ollama` already exposes Ollama on `0.0.0.0:11434` with a health-checkable `/api/tags` endpoint.

### Established Patterns
- Config defaults currently live in checked-in JSON files, not generated at runtime.
- The repo already tests exact config content under `tests/container/`, so config-default changes need matching test updates.

### Integration Points
- Phase 3 will point `.devcontainer/devcontainer.json` at this compose file.
- Phase 4 export/import scripts will need these image reference conventions and compose file paths.

</code_context>

<deferred>
## Deferred Ideas

- Broader persistence of full developer home directories.
- Host port publishing for debugging.
- Automatic GPU/CPU mode switching beyond a simple optional override file.

</deferred>

---

*Phase: 02-compose-stack*
*Context gathered: 2026-04-10*
