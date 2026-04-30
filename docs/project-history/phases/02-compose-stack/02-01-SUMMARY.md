---
phase: 02-compose-stack
plan: 01
subsystem: compose
tags: [docker-compose, podman, devcontainer, ollama, config-runtime, air-gap]

# Dependency graph
requires: []
provides:
  - Base compose stack at .devcontainer/docker-compose.yml with dev-env and ollama services
  - Optional GPU overlay at .devcontainer/docker-compose.gpu.yml
  - Runtime endpoint bridge script that rewrites Pi/OpenCode configs from OLLAMA_HOST
  - Compose-first default Ollama URLs in checked-in Pi/OpenCode config files
affects:
  - 03-devcontainer-integration
  - 04-export-scripts
  - 06-workspace-template

# Tech tracking
tech-stack:
  added:
    - docker compose stack in .devcontainer/
  patterns:
    - Environment-driven image references with inline defaults
    - Health-gated startup via depends_on condition: service_healthy
    - Runtime JSON config rewrite from OLLAMA_HOST for host fallback support
    - Internal-only Ollama service in base compose file

key-files:
  created:
    - .devcontainer/docker-compose.yml
    - .devcontainer/docker-compose.gpu.yml
    - .devcontainer/configure-ollama-endpoint.sh
    - .planning/phases/02-compose-stack/02-CONTEXT.md
    - .planning/phases/02-compose-stack/02-01-PLAN.md
  modified:
    - dot-pi/models.json
    - dot-opencode/config.json
    - tests/container/test_configs.sh
    - tests/container/test_pi.sh
    - tests/container/test_opencode.sh

key-decisions:
  - "Compose-first Ollama default: http://ollama:11434 inside the stack; Windows host remains explicit fallback only"
  - "Compose image references are env-driven so Phase 6 can pin tags without redesign"
  - "Persist only Ollama data and the main dev cache volume in Phase 2"
  - "Keep Ollama internal-only in base compose; no host port publication by default"

requirements-completed:
  - COMPOSE-01
  - COMPOSE-02
  - COMPOSE-03
  - COMPOSE-04
  - COMPOSE-05

# Metrics
duration: 35min
completed: 2026-04-10
---

# Phase 2 Plan 01: Compose Stack Summary

**Added a compose-first two-service stack under `.devcontainer/`, switched Pi/OpenCode defaults to the compose-internal Ollama hostname, and introduced a runtime rewrite script so `OLLAMA_HOST` can still redirect the tools to the Windows host fallback when needed**

## Performance

- **Duration:** ~35 min
- **Tasks:** 1 of 1
- **Files created:** 5
- **Files modified:** 5

## Accomplishments

- Created `.devcontainer/docker-compose.yml` with `dev-env` and `ollama` services on explicit network `ai-net`
- Added health-gated startup so `dev-env` waits for Ollama readiness before running
- Kept the base compose stack internal-only by omitting host port publication for `ollama`
- Added `.devcontainer/docker-compose.gpu.yml` as the minimal optional GPU overlay
- Updated Pi and OpenCode defaults from the Windows host address to `http://ollama:11434/v1`
- Added `.devcontainer/configure-ollama-endpoint.sh` so `OLLAMA_HOST=http://10.10.10.10:11434` rewrites both tool configs at startup without editing the image
- Updated container tests to follow the compose-first default and continue rejecting localhost usage

## Verification

- `docker compose -f .devcontainer/docker-compose.yml config` passes
- `bash -n .devcontainer/configure-ollama-endpoint.sh` passes
- Temp-home validation confirms the script rewrites both Pi and OpenCode configs to `http://10.10.10.10:11434/v1` when `OLLAMA_HOST` is overridden
- Temp-home validation confirms the default path stays `http://ollama:11434/v1`

## Limitations

- I validated compose rendering and config rewrite behavior, but did not run `docker compose up` end-to-end because the required images may not exist locally in this environment
- `.devcontainer/devcontainer.json` still points directly at the prebuilt image; switching VS Code into compose mode remains Phase 3

## Next Phase Readiness

- Phase 3 can now point `devcontainer.json` at `.devcontainer/docker-compose.yml` and list `dev-env` plus `ollama` in `runServices`
- Phase 4 can reuse the env-driven image references and compose file location for export/import workflows

## Self-Check: PASSED

- Base compose file exists and renders successfully
- GPU overlay exists
- Runtime endpoint rewrite script exists, is executable, and passes syntax check
- Pi/OpenCode defaults now target `ollama:11434`

---
*Phase: 02-compose-stack*
*Completed: 2026-04-10*
