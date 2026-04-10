# Phase 4: Export Scripts + CUDA Prep - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement the export-side transport workflow: Bash and PowerShell scripts that package the compose images into a single gzipped archive, generate checksums and a manifest, and bundle any CUDA or driver installers prepared for the offline machine. This phase prepares artifacts for transfer but does not load them on the target machine; import/install execution is Phase 5.

</domain>

<decisions>
## Implementation Decisions

### Archive strategy
- **D-01:** Export uses a single combined `.tar.gz` for the compose image set instead of per-image archives.
- **D-02:** Export emits both a transport archive and a SHA256 checksum artifact so corruption is detectable before import.
- **D-03:** Export also emits `manifest.json` with image references, tags, digests if available, archive metadata, and a list of bundled CUDA/driver installers.

### Source-of-truth behavior
- **D-04:** Export should derive the image set from the compose contract, but remain override-friendly via explicit image arguments or environment variables where needed.
- **D-05:** Scripts must fail fast if Docker is unavailable or the required images do not exist locally.

### CUDA prep scope
- **D-06:** CUDA prep is a separate preparatory step whose downloads are bundled by export when present.
- **D-07:** CUDA prep must document the exact offline-machine discovery commands for GPU model, driver version, kernel version, and OS release.
- **D-08:** GPU detection during prep/export is informational and should not hard-fail CPU-only systems.

### Current repo reality
- **D-09:** Phase 3 verification currently uses a locally built `dev-env` image (`dotfiles-dev-env:local`) and the official `ollama/ollama:0.20.3` image by default because GHCR publication of the baked Ollama image is still blocked.
- **D-10:** Phase 4 should preserve that practical local-export path instead of assuming GHCR availability.

### OpenCode's Discretion
- Exact output directory layout for archive, checksum, manifest, and logs.
- Whether manifest generation is done inline in shell/PowerShell or via a small existing CLI dependency already available in the environment.

</decisions>

<specifics>
## Specific Ideas

- Keep the archive format identical across Bash and PowerShell so either export path can feed either import path.
- Prefer boring, inspectable outputs: archive file, `SHA256SUMS`, `manifest.json`, and an optional `cuda/` payload directory staged before packaging.
- Phase 4 should not depend on the final baked Ollama image being published; it only needs a known local image set to export.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Export Scripts and §CUDA Preparation — EXPORT-01 through EXPORT-04 and CUDA-01 through CUDA-03.
- `.planning/ROADMAP.md` §Phase 4: Export Scripts + CUDA Prep — archive, manifest, checksum, and installer-bundling acceptance criteria.

### Prior phase output
- `.planning/phases/03-devcontainer-integration/03-01-SUMMARY.md` — verified compose-backed devcontainer flow.
- `.planning/phases/03-devcontainer-integration/03-UAT.md` — proof that local compose startup and internal Ollama wiring work.

### Current code
- `.devcontainer/docker-compose.yml` — current source of truth for the image set and runtime defaults.
- `Dockerfile` — local `dev-env` build source now used in verification.
- `.github/workflows/build-container.yml` and `.github/workflows/build-ollama.yml` — canonical image naming patterns when GHCR publication is available.

### Research
- `.planning/research/FEATURES.md` — export/import workflow expectations and manifest contents.
- `.planning/research/PITFALLS.md` — combined tarball gotchas and WSL2 path issues.
- `.planning/research/SUMMARY.md` — single tarball decision and verification checklist.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `setup.sh` and existing shell scripts establish the repo's logging, color, and fail-fast conventions.
- PowerShell profile files exist, but there are no export/import automation scripts yet, so Phase 4 can choose clear top-level script names without compatibility baggage.

### Established Patterns
- Shell automation in this repo uses small helper functions, precondition checks early, and explicit success/failure summaries.
- Tests live under `tests/container/`, so Phase 4 should add targeted validation in the same area when practical.

### Integration Points
- Phase 5 import scripts will consume the archive, checksum, manifest, and bundled installers produced here.
- Phase 6 template docs will need to describe the exact export workflow created in this phase.

</code_context>

<deferred>
## Deferred Ideas

- Per-image tarball exports.
- zstd compression.
- Automatic installation of bundled artifacts during export.

</deferred>

---

*Phase: 04-export-scripts-cuda-prep*
*Context gathered: 2026-04-10*
