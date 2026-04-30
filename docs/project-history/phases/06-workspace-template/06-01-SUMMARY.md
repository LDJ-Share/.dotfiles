---
phase: 06-workspace-template
plan: 01
subsystem: infra
tags: [devcontainer, compose, template, docs, testing]

# Dependency graph
requires:
  - phase: 05-import-scripts
    provides: Offline restore commands and checksum-verified bundle import workflow the template now documents inline
provides:
  - Copyable workspace template under `templates/workspace-template/` that mirrors the compose-first devcontainer contract
  - Inline operator guidance for export, transfer, import, compose startup, VS Code reopen, host fallback, and optional GPU follow-up
  - Static drift coverage for the template contract in the container test suite
affects:
  - onboarding
  - documentation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Template files should mirror the root `.devcontainer/` contract instead of inventing a second stack shape
    - Copyable onboarding artifacts can keep the default path runnable while documenting GHCR pins, host fallback, and GPU as optional examples

key-files:
  created:
    - templates/workspace-template/.devcontainer/docker-compose.yml
    - templates/workspace-template/.devcontainer/devcontainer.json
    - templates/workspace-template/.devcontainer/configure-ollama-endpoint.sh
    - templates/workspace-template/.env.example
    - tests/container/test_workspace_template.sh
    - .planning/phases/06-workspace-template/06-01-SUMMARY.md
  modified:
    - README.md
    - tests/container/run_all.sh

key-decisions:
  - "Keep the template structurally aligned with the production `.devcontainer/` files so new projects copy the existing contract instead of a parallel variant"
  - "Put the end-to-end air-gap runbook directly in template comments and `.env.example` so the artifact stands on its own without a separate template README"
  - "Add static drift checks for the template contract rather than a heavier runtime workflow"

patterns-established:
  - "Template defaults stay CPU-safe and compose-internal; host Ollama and GPU usage remain clearly labeled examples"
  - "Template coverage should verify service names, workspace path, endpoint defaults, and workflow references with focused static tests"

requirements-completed:
  - TMPL-01
  - TMPL-02

# Metrics
duration: 3 min
completed: 2026-04-10
---

# Phase 6 Plan 01: Workspace Template Summary

**Copyable workspace template now mirrors the compose-backed devcontainer stack and documents the full air-gap operator flow inline for new repositories**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-10T10:20:45-05:00
- **Completed:** 2026-04-10T10:23:40-05:00
- **Tasks:** 2 of 2
- **Files modified:** 8

## Accomplishments

- Added `templates/workspace-template/` with copyable `.devcontainer/` assets that preserve `dev-env`, `ollama`, `ai-net`, `/workspace`, and the compose-internal `OLLAMA_HOST` default
- Documented the end-to-end air-gap workflow inline across the template compose file, helper script, and `.env.example`, including `cuda-prep`, export, transfer, import, compose startup, VS Code reopen, GHCR pinning, host fallback, and optional GPU follow-up
- Added `tests/container/test_workspace_template.sh` and wired it into `tests/container/run_all.sh` so template drift is caught alongside the existing container contract checks
- Updated `README.md` so the template is discoverable as the standalone onboarding artifact for other repositories

## Verification

- `bash -n templates/workspace-template/.devcontainer/configure-ollama-endpoint.sh`
- `bash -n tests/container/test_workspace_template.sh`
- `bash tests/container/test_workspace_template.sh`

## task Commits

No git commit was created in this session because the user did not request one.

## Files Created/Modified

- `templates/workspace-template/.devcontainer/docker-compose.yml` - copyable compose template with inline operator guidance and optional examples
- `templates/workspace-template/.devcontainer/devcontainer.json` - copyable VS Code devcontainer contract aligned with the repo's compose-first setup
- `templates/workspace-template/.devcontainer/configure-ollama-endpoint.sh` - helper that keeps Pi and OpenCode aligned with the effective `OLLAMA_HOST`
- `templates/workspace-template/.env.example` - override-friendly example file for local defaults, GHCR pinning, and optional host fallback
- `tests/container/test_workspace_template.sh` - focused static drift checks for the template contract and workflow notes
- `tests/container/run_all.sh` - includes the workspace template test in the aggregate container suite
- `README.md` - points readers at the reusable template artifact

## Decisions Made

- Kept the template close to the root `.devcontainer/` implementation so copying it into another repo preserves the same contract with minimal maintenance overhead
- Used comments and `.env.example` for operator guidance instead of a separate template README to satisfy the standalone-artifact requirement
- Kept host fallback and GPU guidance as optional examples so the no-edit default path stays CPU-safe and compose-internal

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The roadmap now has a reusable onboarding artifact for new repositories that want the same compose-first devcontainer stack
- The template contract is covered by a focused static test, so future compose or devcontainer changes can be mirrored with less drift risk

## Self-Check: PASSED

- The template can be copied into another repo without required edits for the default path
- Service names, workspace path, endpoint defaults, and override strategy stay aligned with the current compose/devcontainer contract
- Inline documentation covers export, transfer, import, compose startup, and VS Code reopen while keeping host fallback and GPU usage optional

---
*Phase: 06-workspace-template*
*Completed: 2026-04-10*
