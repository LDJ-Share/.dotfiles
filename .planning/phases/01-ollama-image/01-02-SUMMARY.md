---
phase: 01-ollama-image
plan: 02
subsystem: infra
tags: [github-actions, docker, ghcr, ollama, buildkit, gha-cache]

# Dependency graph
requires:
  - phase: 01-ollama-image/01-01
    provides: Dockerfile.ollama with pre-baked gemma4 models that this CI workflow builds and validates
provides:
  - GitHub Actions CI workflow that builds, validates, and publishes the Ollama image to GHCR
  - :latest and :sha-{7char} tags at ghcr.io/ldj-share/.dotfiles/ollama-models on master push
affects:
  - 01-ollama-image
  - phase 4

# Tech tracking
tech-stack:
  added:
    - easimon/maximize-build-space@v10
    - docker/build-push-action@v5
    - docker/login-action@v3
    - docker/setup-buildx-action@v3
  patterns:
    - Per-model GHA cache scopes with mode=max
    - Disk maximize action runs before checkout in the build job
    - CI model validation via curl from the runner
    - Publish reuses the tested local image instead of rebuilding
    - Short SHA tag via ${GITHUB_SHA::7} written to GITHUB_ENV

key-files:
  created:
    - .github/workflows/build-ollama.yml
  modified: []

key-decisions:
  - "D-04: Dedicated build-ollama.yml with path-scoped triggers and workflow_dispatch"
  - "D-06: Per-model GHA cache scopes with mode=max to cache intermediate model RUN layers independently"
  - "D-03: Push :latest and :sha-{7char} to ghcr.io/ldj-share/.dotfiles/ollama-models on master push"
  - "T-1-02: Build-space action pinned to @v10; workflow permissions remain contents: read + packages: write"
  - "Publish now promotes the already-tested ollama-models:ci image instead of rebuilding"

patterns-established:
  - "Large-image workflow pattern: maximize disk, build once, validate once, then retag/push the same local image"
  - "Runner-side curl validation against /api/tags before any publish step"
  - "Conditional GHCR login/tag/push steps gated to master pushes"

requirements-completed: [OLLAMA-04]

# Metrics
duration: 10min
completed: 2026-04-09
---

# Phase 1 Plan 02: Ollama Image CI Workflow Summary

**GitHub Actions workflow with per-model BuildKit cache scoping builds the Ollama image, validates both models via `/api/tags`, and publishes the already-tested image to GHCR on master push**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-09T22:00:00Z
- **Completed:** 2026-04-09T22:03:55Z
- **Tasks:** 1/1
- **Files modified:** 1

## Accomplishments

- Created `.github/workflows/build-ollama.yml` with `lint` and `build-and-test` jobs
- Added per-model GHA cache scopes (`ollama-gemma4-26b`, `ollama-gemma4-e4b`) with `mode=max`
- Validated both models from the runner through `/api/tags` before any publish step can run
- Hardened the workflow after review by pinning `maximize-build-space` to `@v10`
- Publication now retags and pushes the already-tested `ollama-models:ci` image instead of rebuilding for GHCR

## Task Commits

Each task was committed atomically:

1. **Task 1: Create build-ollama.yml CI workflow** - `0d694cc` (ci)

## Files Created/Modified

- `.github/workflows/build-ollama.yml` - CI workflow with path-scoped triggers, per-model cache scopes, model validation, and conditional GHCR publication from the tested image

## Decisions Made

- Followed the locked trigger, tag, and cache-scope decisions from `01-CONTEXT.md`
- Kept publication gated to master pushes only
- Resolved the earlier review concerns by making publish a promotion of the tested artifact instead of a second build

## Deviations from Plan

- Final implementation keeps publication in conditional steps inside `build-and-test` rather than a separate `publish` job so the pushed image is the same one that passed validation.

## Issues Encountered

- Initial review found workflow hardening and artifact-promotion issues; those have been resolved in the current file.

## User Setup Required

- None beyond the standard GitHub Actions `GITHUB_TOKEN` provided automatically in the repository.

## Next Phase Readiness

- Phase 1 is structurally complete and ready for live human verification
- After runtime and CI confirmation, Phase 2 can consume `ghcr.io/ldj-share/.dotfiles/ollama-models`

## Self-Check: PASSED

- `.github/workflows/build-ollama.yml` exists
- Current workflow validates before publish
- Current workflow promotes the tested image for GHCR publication

---
*Phase: 01-ollama-image*
*Completed: 2026-04-09*
