---
phase: 01-ollama-image
plan: 02
subsystem: infra
tags: [github-actions, docker, ghcr, ollama, buildkit, gha-cache]

# Dependency graph
requires:
  - phase: 01-ollama-image/01-01
    provides: Dockerfile.ollama with pre-baked gemma4 models that this CI workflow builds and publishes
provides:
  - GitHub Actions CI workflow that builds, validates, and publishes the Ollama image to GHCR
  - :latest and :sha-{7char} tags at ghcr.io/ldj-share/.dotfiles/ollama-models on master push
affects:
  - 01-ollama-image (completes the CI/CD publish loop for the Ollama image)
  - phase 4 (export scripts pull from the GHCR tags this workflow publishes)

# Tech tracking
tech-stack:
  added:
    - easimon/maximize-build-space@master (reclaim 40GB+ on ubuntu-latest for 27GB+ builds)
    - docker/build-push-action@v5 (BuildKit build with GHA cache backend)
    - docker/login-action@v3 (GHCR auth)
    - docker/setup-buildx-action@v3 (BuildKit driver setup)
  patterns:
    - Per-model GHA cache scopes (scope=ollama-gemma4-26b, scope=ollama-gemma4-e4b) with mode=max
    - Disk maximize action MUST appear as the first step before actions/checkout in any job running docker build
    - CI model validation via curl from runner (not inside container) — curl absent from ollama/ollama base image
    - Short SHA tag via ${GITHUB_SHA::7} written to GITHUB_ENV
    - Lowercase GHCR owner normalization via tr '[:upper:]' '[:lower:]'

key-files:
  created:
    - .github/workflows/build-ollama.yml
  modified: []

key-decisions:
  - "D-04: Dedicated build-ollama.yml — does not extend build-container.yml; path triggers on Dockerfile.ollama and build-ollama.yml only"
  - "D-06: Per-model GHA cache scopes with mode=max to cache intermediate model RUN layers independently"
  - "D-03: Push :latest and :sha-{7char} to ghcr.io/ldj-share/.dotfiles/ollama-models on every master push"
  - "T-1-02: GITHUB_TOKEN scoped to packages: write + contents: read only — no contents: write"
  - "D-09: GHCR 10GB-per-layer limit — documented in publish job output; Docker client splits automatically"

patterns-established:
  - "Pattern: easimon/maximize-build-space must be the FIRST step (before checkout) in any job doing docker build of large images"
  - "Pattern: Per-model GHA cache scopes prevent cross-model cache invalidation on 27GB+ images"
  - "Pattern: Validate models from runner using curl against /api/tags (not from inside container)"

requirements-completed: [OLLAMA-04]

# Metrics
duration: 10min
completed: 2026-04-09
---

# Phase 1 Plan 02: Ollama Image CI Workflow Summary

**GitHub Actions workflow with per-model BuildKit cache scoping publishes pre-baked Ollama image (:latest + :sha-{7char}) to GHCR on master push with model validation via /api/tags**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-09T22:00:00Z
- **Completed:** 2026-04-09T22:03:55Z
- **Tasks:** 1/1
- **Files modified:** 1

## Accomplishments
- Created `.github/workflows/build-ollama.yml` with three jobs: lint (ShellCheck pass-through), build-and-test, publish
- Per-model GHA cache scopes (ollama-gemma4-26b, ollama-gemma4-e4b) with mode=max prevent 30+ min full rebuilds when only one model changes
- Model validation step probes /api/tags from the runner (curl on ubuntu-latest) to confirm both gemma4:26b and gemma4:e4b are present before publish
- GITHUB_TOKEN scoped to packages: write + contents: read only (T-1-02 mitigated)
- easimon/maximize-build-space runs as first step in both build-and-test and publish jobs before actions/checkout

## Task Commits

Each task was committed atomically:

1. **Task 1: Create build-ollama.yml CI workflow** - `0d694cc` (ci)

## Files Created/Modified
- `.github/workflows/build-ollama.yml` - CI workflow: lint + build-and-test + publish jobs; per-model GHA cache scopes; model validation; GHCR publish with :latest and :sha-{7char} tags

## Decisions Made
- Followed all locked decisions (D-03, D-04, D-06, D-09) from 01-CONTEXT.md exactly as specified
- Threat mitigation T-1-02 applied: packages: write only, no contents: write
- workflow_dispatch included for manual model version bump triggers (D-04 requirement)

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
None — all acceptance criteria passed on first attempt. YAML syntax valid (python3 yaml.safe_load).

## User Setup Required
None — no external service configuration required beyond the existing GITHUB_TOKEN available automatically in GitHub Actions.

## Next Phase Readiness
- CI workflow is ready; will trigger on any push to Dockerfile.ollama
- Requires plan 01-01 (Dockerfile.ollama) to be merged to master before the publish job will produce a valid image
- Both :latest and :sha-{7char} GHCR tags will be available for Phase 4 export scripts once 01-01 + 01-02 land on master

## Self-Check: PASSED

All files and commits verified:
- `.github/workflows/build-ollama.yml` — exists
- `.planning/phases/01-ollama-image/01-02-SUMMARY.md` — exists
- Commit `0d694cc` — confirmed in git log

---
*Phase: 01-ollama-image*
*Completed: 2026-04-09*
