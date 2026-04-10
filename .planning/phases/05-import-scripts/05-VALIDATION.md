---
phase: 5
slug: import-scripts
status: current
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-10
updated: 2026-04-10T15:36:11Z
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for the offline bundle restore workflow.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash syntax checks, help-text checks, and import contract tests |
| **Config files** | `image-import.sh`, `image-import.ps1` |
| **Quick run command** | `bash -n image-import.sh && bash ./image-import.sh --help` |
| **Full suite command** | `bash tests/container/test_import_scripts.sh` |
| **Estimated runtime** | < 1 min |

---

## Sampling Rate

- **After every import-script edit:** Re-run `bash -n image-import.sh` and the focused import contract test
- **After every CUDA-handling edit:** Re-check `metadata.json`, `SHA256SUMS`, and `cuda-prep` guidance references
- **Before milestone verification:** Confirm the restore path still validates compose only after `docker load`
- **Max feedback latency:** < 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 5-01 | 01 | 1 | IMPORT-01 | Bash import verifies checksums, restores images, and validates compose | Structural | `bash -n image-import.sh && bash tests/container/test_import_scripts.sh` | ✅ | ✅ green |
| 5-02 | 01 | 1 | IMPORT-02 | PowerShell import mirrors the same restore contract | Structural | `grep -q 'docker load' image-import.ps1 && grep -q 'docker compose' image-import.ps1` | ✅ | ✅ green |
| 5-03 | 01 | 1 | IMPORT-03 | CUDA payload handling is explicit for present and missing installers | Structural | `grep -q 'metadata.json' image-import.sh && grep -q 'cuda-prep' image-import.sh && grep -q 'metadata.json' image-import.ps1` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `image-import.sh` exists
- [x] `image-import.ps1` exists
- [x] Validation coverage exists for checksum-before-load, compose-after-load, and CUDA rerun guidance
- [x] Focused import contract test is wired into the repo suite

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| End-to-end offline restore with a real exported bundle | IMPORT-01, IMPORT-03 | Requires a concrete bundle and local Docker daemon with image load permission | Run `bash ./image-import.sh <bundle>.tar.gz` on a disconnected machine and inspect restore output |
| PowerShell runtime execution | IMPORT-02, IMPORT-03 | `pwsh` is unavailable in this workspace | Run `pwsh -File .\image-import.ps1 <bundle>.tar.gz` on a Windows or PowerShell-capable host |

---

## Validation Sign-Off

- [x] All requirements have automated structural coverage or an explicit manual-only gate
- [x] Sampling continuity is preserved
- [x] Wave 0 coverage is complete
- [x] No watch-mode steps are required
- [x] Fast feedback is available in under 300 seconds
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved for static verification; live bundle import and PowerShell runtime remain human follow-up only
