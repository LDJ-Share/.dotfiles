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
  - GitHub Actions CI workflow intended to build, validate, and publish the Ollama image to GHCR
  - Evidence that GitHub-hosted runners exhaust disk before the workflow can validate or publish the image
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

requirements-completed: []

# Metrics
duration: 10min
completed: 2026-04-09
---

# Phase 1 Plan 02: Ollama Image CI Workflow Summary

**GitHub Actions workflow exists for the Ollama image, but the first master publish attempt proved the current GitHub-hosted runner path is blocked by disk exhaustion before validation or GHCR push can occur**

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
- Master run `24223620363` on `master` failed in `Build and Test` -> `Build image` before validation and publish.
- Evidence from the failed run:
  - `Maximize build disk space` reported `/dev/root` at `145G 145G 100M 100% /` while the workspace mount had `104G` free.
  - BuildKit then failed with `failed to copy: write /var/lib/docker/buildkit/content/ingest/.../data: no space left on device`.
  - The failing copy happened while pulling the `ollama/ollama:0.20.3` base layer (`3.50GB` transfer in the log), so the job never reached model validation or GHCR push.

## User Setup Required

- Until GHCR publication is unblocked, use a connected staging machine to pull the required Ollama models manually before export.

## Next Phase Readiness

- Phase 1 code artifacts are in place, but OLLAMA-04 is blocked on GitHub-hosted runner disk limits.
- Phase 2 may proceed now, treating manual model pull on a connected staging machine as the temporary source of Ollama content.

## Self-Check: PASSED

- `.github/workflows/build-ollama.yml` exists
- Current workflow validates before publish
- Current workflow promotes the tested image for GHCR publication

---
*Phase: 01-ollama-image*
*Completed: 2026-04-09*
