---
phase: 04-export-scripts-cuda-prep
plan: 01
subsystem: infra
tags: [docker, export, checksum, powershell, cuda]

# Dependency graph
requires:
  - phase: 03-devcontainer-integration
    provides: Compose-backed local image defaults and devcontainer service contract
provides:
  - Single archive export workflow for the local compose image set
  - Shared manifest and checksum contract for offline transport
  - Predictable CUDA staging payload for later import bundling
affects:
  - 05-import-scripts
  - 06-workspace-template

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Bash and PowerShell transport scripts emit the same archive layout and metadata file names
    - Offline GPU artifacts are staged under .airgap-artifacts/cuda for direct bundling

key-files:
  created:
    - image-export.sh
    - image-export.ps1
    - cuda-prep.sh
    - cuda-prep.ps1
    - tests/container/test_export_scripts.sh
    - .planning/phases/04-export-scripts-cuda-prep/04-01-SUMMARY.md
  modified:
    - README.md
    - .gitignore
    - tests/container/run_all.sh

key-decisions:
  - "Use .airgap-artifacts/ as the shared staging root so export and CUDA prep can cooperate without polluting tracked files"
  - "Keep the image list override-friendly while defaulting to dotfiles-dev-env:local and ollama/ollama:0.20.3 so export works before GHCR publication is restored"
  - "Require explicit download URLs for CUDA artifacts so the staged payload stays inspectable and reproducible across Bash and PowerShell"

patterns-established:
  - "Transport scripts should emit archive, manifest, and checksum artifacts side by side with identical names across shells"
  - "CUDA prep should always write OFFLINE-DISCOVERY.txt, metadata.json, and SHA256SUMS before export bundles the payload"

requirements-completed:
  - EXPORT-01
  - EXPORT-02
  - EXPORT-03
  - EXPORT-04
  - CUDA-01
  - CUDA-02
  - CUDA-03

# Metrics
duration: 3 min
completed: 2026-04-10
---

# Phase 4 Plan 01: Export Scripts + CUDA Prep Summary

**Added cross-shell transport scripts that package the local compose images into one offline archive and stage optional CUDA installers in a bundle-ready directory with matching metadata**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-10T14:42:11Z
- **Completed:** 2026-04-10T14:44:47Z
- **Tasks:** 2 of 2
- **Files modified:** 8

## Accomplishments

- Added `image-export.sh` and `image-export.ps1` to save the current compose image set into a single `.tar.gz` transport bundle
- Standardized the export contract around sibling archive, manifest, and SHA256 files plus an internal payload containing `images.tar`, `manifest.json`, and optional `cuda/`
- Added `cuda-prep.sh` and `cuda-prep.ps1` to stage Linux and Windows GPU artifacts in `.airgap-artifacts/cuda/` with discovery instructions and metadata
- Added a focused container test and wired it into `tests/container/run_all.sh` so the new contract is checked with the rest of the repo tests
- Documented the staging and export workflow in `README.md` for both Bash and PowerShell paths

## Verification

- `bash -n image-export.sh`
- `bash -n cuda-prep.sh`
- `bash tests/container/test_export_scripts.sh`

## task Commits

Each task was committed atomically:

1. **task 1: Build the archive export contract** - `4f4b3b7` (feat)
2. **task 2: Build CUDA prep staging for export bundling** - `4204b0c` (feat)

## Files Created/Modified

- `image-export.sh` - Bash export workflow that saves images, writes manifest metadata, and emits SHA256 verification data
- `image-export.ps1` - PowerShell export workflow matching the Bash archive contract
- `cuda-prep.sh` - Bash CUDA staging workflow that writes offline discovery guidance, metadata, and staged downloads
- `cuda-prep.ps1` - PowerShell CUDA staging workflow matching the Bash payload contract
- `tests/container/test_export_scripts.sh` - contract checks for the new export and CUDA prep files
- `tests/container/run_all.sh` - includes the new export contract test in the container test suite
- `README.md` - documents the Phase 4 transport archive and CUDA staging workflow
- `.gitignore` - ignores `.airgap-artifacts/` so generated export payloads stay out of source control

## Decisions Made

- Used one shared `.airgap-artifacts/` root to keep export outputs and CUDA staging predictable across shells
- Kept export defaults aligned with the current local-compose image names so the workflow works before GHCR publication resumes
- Modeled CUDA prep around explicit artifact URLs to keep offline payload selection reproducible instead of hiding NVIDIA download resolution behind brittle shell logic

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Ignored generated transport artifacts in git**
- **Found during:** task 1 (Build the archive export contract)
- **Issue:** The plan introduced repo-local export and CUDA staging directories, but without an ignore rule the generated archives and installers would appear as untracked files after normal use
- **Fix:** Added `.airgap-artifacts/` to `.gitignore`
- **Files modified:** `.gitignore`
- **Verification:** `git status --short` stays clean after code commits and only planning metadata remains pending
- **Committed in:** `4f4b3b7`

**2. [Rule 2 - Missing Critical] Wired the new contract test into the aggregate test runner**
- **Found during:** task 1 (Build the archive export contract)
- **Issue:** A standalone test file would be easy to miss if `tests/container/run_all.sh` did not invoke it with the rest of the suite
- **Fix:** Added `test_export_scripts.sh` to `tests/container/run_all.sh`
- **Files modified:** `tests/container/run_all.sh`
- **Verification:** `bash tests/container/test_export_scripts.sh` passes and `run_all.sh` now includes the new test entry
- **Committed in:** `4f4b3b7`

---

**Total deviations:** 2 auto-fixed (2 Rule 2 missing critical)
**Impact on plan:** Both auto-fixes tightened the transport workflow without changing scope. The archive contract and CUDA payload remain aligned with the planned deliverables.

## Issues Encountered

- `pwsh` is not installed in this workspace, so I could not execute the PowerShell scripts directly here. The PowerShell files were verified statically via the contract test, but runtime execution on a PowerShell-capable host is still recommended.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 5 now has a concrete archive contract to consume: sibling `.tar.gz`, `manifest.json`, and `SHA256SUMS` artifacts plus an internal payload with `images.tar` and optional `cuda/`
- Import work can assume CUDA payloads, when present, arrive pre-staged under the same directory layout from either Bash or PowerShell export paths

## Self-Check: PASSED

- The repo now contains Bash and PowerShell export scripts for the same archive layout
- The export contract includes manifest and checksum artifacts plus optional CUDA bundle metadata
- CUDA prep writes a predictable staging directory with offline discovery commands and checksums ready for export

---
*Phase: 04-export-scripts-cuda-prep*
*Completed: 2026-04-10*
