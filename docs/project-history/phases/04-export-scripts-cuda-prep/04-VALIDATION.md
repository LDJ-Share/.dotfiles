---
phase: 4
slug: export-scripts-cuda-prep
status: current
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-10
updated: 2026-04-10T15:36:11Z
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for the offline export bundle and CUDA staging scripts.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash syntax checks and focused contract tests |
| **Config files** | `image-export.sh`, `image-export.ps1`, `cuda-prep.sh`, `cuda-prep.ps1` |
| **Quick run command** | `bash -n image-export.sh && bash -n cuda-prep.sh` |
| **Full suite command** | `bash tests/container/test_export_scripts.sh` |
| **Estimated runtime** | < 1 min |

---

## Sampling Rate

- **After every export-script edit:** Re-run `bash -n image-export.sh` and `bash tests/container/test_export_scripts.sh`
- **After every CUDA-prep edit:** Re-run `bash -n cuda-prep.sh` and re-check discovery-command references
- **Before milestone verification:** Confirm both shells still advertise the same archive contract and metadata filenames
- **Max feedback latency:** < 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 4-01 | 01 | 1 | EXPORT-01 | Bash export emits a single archive contract for the compose image set | Structural | `bash -n image-export.sh && grep -q 'dotfiles-dev-env:local' image-export.sh && grep -q 'ollama/ollama:0.20.3' image-export.sh` | ✅ | ✅ green |
| 4-02 | 01 | 1 | EXPORT-02 | PowerShell export mirrors the same archive contract | Structural | `grep -q 'manifest.json' image-export.ps1 && grep -q 'SHA256SUMS' image-export.ps1` | ✅ | ✅ green |
| 4-03 | 01 | 1 | EXPORT-03 | Export writes `manifest.json` and checksum metadata | Structural | `bash tests/container/test_export_scripts.sh` | ✅ | ✅ green |
| 4-04 | 01 | 1 | EXPORT-04 | Export bundles staged CUDA payloads without translation | Structural | `grep -q 'cuda' image-export.sh && grep -q 'cuda' image-export.ps1` | ✅ | ✅ green |
| 4-05 | 01 | 1 | CUDA-01 | Bash/PowerShell CUDA prep accept target-machine inputs and stage downloads | Structural | `grep -q 'LinuxToolkitUrl' cuda-prep.ps1 && grep -q -- '--linux-toolkit-url' cuda-prep.sh` | ✅ | ✅ green |
| 4-06 | 01 | 1 | CUDA-02 | Windows driver artifact is part of the staged payload contract | Structural | `grep -q 'WindowsDriverUrl' cuda-prep.ps1 && grep -q -- '--windows-driver-url' cuda-prep.sh` | ✅ | ✅ green |
| 4-07 | 01 | 1 | CUDA-03 | Offline-machine discovery commands are documented inline | Structural | `grep -q 'nvidia-smi --query-gpu=name --format=csv,noheader' cuda-prep.sh && grep -q 'lsb_release -rs' cuda-prep.sh` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] All four export/CUDA scripts exist
- [x] Validation coverage exists for archive metadata, shared artifact naming, and offline discovery guidance
- [x] The focused export contract test is wired into the repo test suite

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live export with real local images present | EXPORT-01, EXPORT-03, EXPORT-04 | Requires the referenced images to exist locally | Run `bash ./image-export.sh --output-dir <dir>` and inspect the emitted bundle, manifest, and checksums |
| PowerShell runtime execution | EXPORT-02, CUDA-01, CUDA-02 | `pwsh` is unavailable in this workspace | Run `pwsh -File .\image-export.ps1 ...` and `pwsh -File .\cuda-prep.ps1 ...` on a PowerShell-capable host |

---

## Validation Sign-Off

- [x] All requirements have automated structural coverage or an explicit manual-only gate
- [x] Sampling continuity is preserved
- [x] Wave 0 coverage is complete
- [x] No watch-mode steps are required
- [x] Fast feedback is available in under 300 seconds
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved for static verification; live export and PowerShell runtime remain human follow-up only
