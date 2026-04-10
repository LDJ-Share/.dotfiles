---
phase: 05-import-scripts
plan: 01
subsystem: infra
tags: [docker, compose, import, powershell, cuda]

# Dependency graph
requires:
  - phase: 04-export-scripts-cuda-prep
    provides: Shared archive, manifest, checksum, and CUDA payload contract
provides:
  - Offline import scripts for Bash and PowerShell that verify, restore, and validate the compose bundle
  - Host-specific CUDA or driver handling with checksum verification and rerun guidance
affects:
  - 06-workspace-template

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Bash and PowerShell import scripts consume the same sibling archive, manifest, and SHA256 contract
    - Import validates compose after docker load and treats CUDA installation as optional host-specific follow-up

key-files:
  created:
    - image-import.sh
    - image-import.ps1
    - tests/container/test_import_scripts.sh
    - .planning/phases/05-import-scripts/05-01-SUMMARY.md
  modified:
    - README.md
    - tests/container/run_all.sh

key-decisions:
  - "Keep the import scripts self-contained so the offline operator can inspect every verification and restore step without extra helpers"
  - "Validate the compose contract after docker load and report resolved services and images instead of implicitly starting the stack"
  - "Handle CUDA payloads explicitly per host: Bash installs Linux artifacts, PowerShell installs the Windows driver, and both warn with cuda-prep guidance when installers are missing"

patterns-established:
  - "Import scripts must fail before extraction or docker load on checksum mismatch"
  - "Cross-shell transport workflows should share the same manifest and payload layout while keeping host-specific install steps explicit"

requirements-completed:
  - IMPORT-01
  - IMPORT-02
  - IMPORT-03

# Metrics
duration: 5 min
completed: 2026-04-10
---

# Phase 5 Plan 01: Import Scripts Summary

**Offline bundle import now verifies sibling checksums, restores compose images from `images.tar`, validates the compose contract, and handles optional CUDA or driver payloads with host-specific guidance**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-10T09:53:00-05:00
- **Completed:** 2026-04-10T09:57:40-05:00
- **Tasks:** 2 of 2
- **Files modified:** 5

## Accomplishments

- Added `image-import.sh` and `image-import.ps1` to verify sibling `SHA256SUMS` and manifest data before extraction or `docker load`
- Restored images from the exported `images.tar` payload and validated `.devcontainer/docker-compose.yml` while reporting discovered services and image availability
- Added optional CUDA or driver handling that verifies `metadata.json` and payload checksums, runs host-appropriate installers, and warns with `cuda-prep` rerun guidance when installers are missing
- Added a focused import contract test and wired it into `tests/container/run_all.sh`
- Extended the README deployment flow so the target machine restore path is explicit for both Bash and PowerShell

## Verification

- `bash -n image-import.sh`
- `bash tests/container/test_import_scripts.sh`

## task Commits

Each task was committed atomically:

1. **task 1: Build the archive verification and image restore workflow** - `fb646d1` (feat)
2. **task 2: Add optional CUDA and driver installation handling** - `812cb5e` (feat)

## Files Created/Modified

- `image-import.sh` - Bash offline import workflow that verifies the bundle, restores images, validates compose, and handles Linux-side CUDA payloads
- `image-import.ps1` - PowerShell import workflow matching the same restore contract and Windows driver path
- `tests/container/test_import_scripts.sh` - contract checks for the new import scripts and README guidance
- `tests/container/run_all.sh` - includes the import contract test in the aggregate container test runner
- `README.md` - documents the target-machine restore workflow and optional CUDA handling

## Decisions Made

- Kept the restore path non-destructive by validating compose syntax and image availability instead of automatically starting the stack during import
- Used the exported manifest and sibling checksum files as the source of truth so archive corruption fails before extraction or image load
- Kept CUDA handling explicit by host rather than hiding Linux and Windows installers behind one opaque path

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `pwsh` is not installed in this workspace, so the PowerShell import script could only be verified statically here. Runtime execution on a Windows PowerShell-capable host is still recommended.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 6 can now document a concrete end-to-end transport workflow that includes export, transfer, import, and compose validation
- The workspace template can reference stable `image-import.sh` and `image-import.ps1` command surfaces instead of inventing restore steps later

## Self-Check: PASSED

- Bash and PowerShell import scripts now consume the same sibling archive contract
- The import flow fails before `docker load` on checksum mismatch and validates the compose file after restore
- Optional CUDA payload handling is explicit for bundled installers, missing installers, and CPU-only imports

---
*Phase: 05-import-scripts*
*Completed: 2026-04-10*
