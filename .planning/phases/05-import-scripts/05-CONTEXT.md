# Phase 5: Import Scripts - Context

**Gathered:** 2026-04-10
**Status:** Ready for execution

<domain>
## Phase Boundary

Implement the offline-machine side of the transport workflow: verify the exported archive before loading anything, import the bundled images, validate the compose configuration against the restored image set, and run bundled CUDA or driver installers when they are present. This phase consumes the Phase 4 archive contract; it does not redesign export or author the final reusable workspace template.

</domain>

<decisions>
## Implementation Decisions

### Archive contract
- **D-01:** Import must consume the Phase 4 sibling artifacts: `<bundle>.tar.gz`, `<bundle>-manifest.json`, and `<bundle>-SHA256SUMS`.
- **D-02:** SHA256 verification happens before archive extraction or `docker load` so corrupted media fails fast.
- **D-03:** The archive payload layout is fixed: `<bundle>/images.tar`, `<bundle>/manifest.json`, and optional `<bundle>/cuda/`.

### Import behavior
- **D-04:** Bash and PowerShell imports must follow the same high-level flow and accept equivalent inputs so either export path can feed either import path.
- **D-05:** Compose validation should target `.devcontainer/docker-compose.yml` after images are loaded, because image references may not exist beforehand on an air-gapped machine.
- **D-06:** Service status reporting should be non-destructive and informative; prefer config validation plus compose/service inspection over implicit long-running orchestration unless required to satisfy the acceptance path.

### CUDA and driver handling
- **D-07:** If a bundled `cuda/` payload is present, import should use its metadata and checksums to drive installation rather than guessing filenames.
- **D-08:** If GPU-related metadata exists but installers are missing, import must warn clearly and tell the user to re-run `cuda-prep` with the required URLs.
- **D-09:** CPU-only machines remain a valid path; missing CUDA payloads must not fail a CPU-only import.

### Current repo reality
- **D-10:** Phase 4 defaults still export `dotfiles-dev-env:local` and `ollama/ollama:0.20.3`, so import planning must support both the temporary local-image path and the eventual GHCR-backed path.
- **D-11:** PowerShell runtime verification is still limited in this workspace because `pwsh` is unavailable locally, so tests should stay mostly contract-focused unless a portable validation path exists.

### OpenCode's Discretion
- Whether to add a small shared helper script/module for manifest parsing or keep each import script self-contained.
- Whether compose status reporting should use `docker compose config`, `docker compose images`, `docker compose ps`, or a minimal combination.

</decisions>

<specifics>
## Specific Ideas

- Reuse the repo's existing shell-script conventions: precondition checks first, short helper functions, and clear success/warn/error output.
- Keep the archive handling boring and inspectable: verify checksum, extract to a temp workspace, read the payload manifest, then load images.
- Treat CUDA installation as optional post-load work so the core import path remains reliable even on CPU-only systems.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` Section Import Scripts - IMPORT-01 through IMPORT-03.
- `.planning/ROADMAP.md` Section Phase 5: Import Scripts - offline validation, image load, compose validation, and CUDA/driver behavior.

### Prior phase output
- `.planning/phases/04-export-scripts-cuda-prep/04-01-SUMMARY.md` — defines the delivered archive contract and known verification gaps.
- `.planning/phases/04-export-scripts-cuda-prep/04-01-PLAN.md` — original export-side contract details Phase 5 must consume.

### Current code
- `image-export.sh` — Bash source of truth for archive names, payload layout, and manifest/checksum generation.
- `image-export.ps1` — PowerShell export contract that Phase 5 should mirror.
- `cuda-prep.sh` and `cuda-prep.ps1` — define CUDA payload layout, metadata, and checksum files.
- `.devcontainer/docker-compose.yml` — compose file the import workflow must validate after images are restored.
- `tests/container/test_export_scripts.sh` — current contract checks that describe what Phase 5 can safely assume about export outputs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `image-export.sh` already records `archive_sha256`, image references, and bundled CUDA file checksums that import can trust and re-verify.
- `cuda-prep.sh` writes `metadata.json`, `OFFLINE-DISCOVERY.txt`, and `SHA256SUMS`, giving import enough structure to warn or install deterministically.

### Established Patterns
- Top-level automation scripts in this repo use direct helper functions instead of extra abstraction layers.
- Tests under `tests/container/` are mostly static and contract-focused; Phase 5 can extend that style before adding heavier runtime checks.

### Integration Points
- Phase 6 template documentation will need the exact command surface and expectations established here.
- The offline workflow depends on the import script consuming Phase 4 outputs without extra manual renaming or repackaging.

</code_context>

<deferred>
## Deferred Ideas

- Per-image selective import.
- Alternative runtimes beyond the current Docker-first flow.
- Smarter auto-detection of NVIDIA installer filenames beyond the explicit Phase 4 payload metadata.

</deferred>

---

*Phase: 05-import-scripts*
*Context gathered: 2026-04-10*
