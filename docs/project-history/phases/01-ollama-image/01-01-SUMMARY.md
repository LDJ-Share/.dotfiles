---
phase: 01-ollama-image
plan: 01
subsystem: infra
tags: [docker, ollama, gemma4, air-gap, ghcr, buildkit]

# Dependency graph
requires: []
provides:
  - Dockerfile.ollama at repository root with pre-baked gemma4:26b and gemma4:e4b model blobs
  - ollama/ollama:0.20.3 base image pinned for reproducible builds
  - OLLAMA_HOST=0.0.0.0:11434 binding for compose sidecar integration
  - HEALTHCHECK on /api/tags using curl
affects:
  - 01-02 (CI workflow for building and publishing Dockerfile.ollama to GHCR)
  - 02-compose-stack (references ollama-models image from GHCR)
  - 04-export-scripts (saves ollama-models image for air-gap transport)

# Tech tracking
tech-stack:
  added:
    - ollama/ollama:0.20.3 (base image)
  patterns:
    - Background-serve + retry-loop pattern for baking Ollama models into Docker build layers
    - One RUN layer per model for independent GHA cache scoping (D-02)
    - Build-time server on non-production port (127.0.0.1:11235) to avoid ENV collision

key-files:
  created:
    - Dockerfile.ollama
  modified: []

key-decisions:
  - "Pin FROM ollama/ollama:0.20.3 (exact semver) — prevents mutable :latest tag substitution (T-1-01)"
  - "One RUN layer per model — gemma4:26b and gemma4:e4b in separate layers for independent GHA cache"
  - "Build-time server on 127.0.0.1:11235 — avoids port collision with final ENV OLLAMA_HOST=0.0.0.0:11434"
  - "curl installed via apt for HEALTHCHECK — absent from ollama/ollama base image"
  - "No GPU directives in Dockerfile — GPU passthrough is runtime concern handled by NVIDIA Container Toolkit"

patterns-established:
  - "Background-serve pattern: ollama serve & / retry loop using ollama ls / pull / kill+wait"
  - "Dockerfile header comment style: full-width = separators, PURPOSE/Published to/GPU/BUILD sections"

requirements-completed:
  - OLLAMA-01
  - OLLAMA-02
  - OLLAMA-03

# Metrics
duration: 15min
completed: 2026-04-09
---

# Phase 01 Plan 01: Ollama Image Summary

**Dockerfile.ollama pre-bakes gemma4:26b and gemma4:e4b into ollama/ollama:0.20.3 using a background-serve + retry loop pattern, bound to 0.0.0.0:11434 with curl HEALTHCHECK**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-09T22:10:00Z
- **Completed:** 2026-04-09T22:25:00Z
- **Tasks:** 1 of 1
- **Files modified:** 1

## Accomplishments

- Dockerfile.ollama created at repository root with both gemma4 models baked in at build time
- All 11 acceptance criteria pass (base image pin, two separate RUN layers, build-time port isolation, ENV binding order, HEALTHCHECK, no device_requests)
- T-1-01 threat mitigation applied: exact semver `ollama/ollama:0.20.3` prevents mutable tag substitution

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Dockerfile.ollama with pre-baked gemma4 models** - `2f030f7` (feat)

## Files Created/Modified

- `Dockerfile.ollama` - Single-stage Dockerfile building Ollama image with gemma4:26b and gemma4:e4b baked in at build time, curl installed for HEALTHCHECK, ENV OLLAMA_HOST=0.0.0.0:11434

## Decisions Made

- Followed all locked decisions D-01 through D-09 as specified in plan interfaces
- Used `ollama ls` as build-time readiness probe (curl absent from base image per ollama/ollama#9781)
- 30-retry loop with 2s sleep per iteration (60s total window) — sufficient for CI runner startup variance

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Dockerfile.ollama ready for CI workflow integration (Plan 01-02: build-ollama.yml)
- GHCR image name established: `ghcr.io/ldj-share/.dotfiles/ollama-models`
- Phase 2 (Compose Stack) can reference the published image tag in docker-compose.yml

## Self-Check: PASSED

- `Dockerfile.ollama` exists: FOUND
- Commit `2f030f7` exists: FOUND
- All 11 acceptance criteria verified by automated grep checks

---
*Phase: 01-ollama-image*
*Completed: 2026-04-09*
