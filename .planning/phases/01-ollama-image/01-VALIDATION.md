---
phase: 1
slug: ollama-image
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash scripts + `curl` smoke test (infrastructure phase — no unit test framework) |
| **Config file** | None — validation is inline CI steps in `build-ollama.yml` |
| **Quick run command** | `docker run --rm -p 11434:11434 ollama-models:ci` + curl probe |
| **Full suite command** | Full `build-ollama.yml` CI run |
| **Estimated runtime** | ~30–40 min (dominated by model pull on cache miss) |

---

## Sampling Rate

- **After every task commit:** Run `docker build -f Dockerfile.ollama --target base .` (lint/syntax check)
- **After every plan wave:** Run local smoke test (`docker run` + `/api/tags` probe)
- **Before `/gsd-verify-work`:** Full CI run must be green
- **Max feedback latency:** ~5 min for local smoke; ~40 min for full CI

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01 | 01 | 1 | OLLAMA-01 | T-1-01 | Base image pinned to semver; no `:latest` | Smoke | `curl -sf http://localhost:11434/api/tags \| grep -q gemma4:26b && grep -q gemma4:e4b` | ❌ W0 | ⬜ pending |
| 1-02 | 01 | 1 | OLLAMA-02 | — | CPU fallback confirmed without GPU device | Smoke | Container starts successfully; `/api/tags` responds | ❌ W0 | ⬜ pending |
| 1-03 | 01 | 1 | OLLAMA-03 | — | Server bound to `0.0.0.0:11434` (not 127.0.0.1) | Smoke | `curl http://localhost:11434/api/tags` from runner via port map | ❌ W0 | ⬜ pending |
| 1-04 | 01 | 1 | OLLAMA-04 | T-1-02 | GITHUB_TOKEN scoped to `packages: write` only | Integration | GHA workflow completes; `docker pull ghcr.io/.../ollama-models:sha-<7char>` succeeds | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Dockerfile.ollama` — does not exist yet; Wave 0 creates it
- [ ] `.github/workflows/build-ollama.yml` — does not exist yet; Wave 0 creates it
- [ ] No existing test scripts to ShellCheck for Phase 1 (all validation is inline CI steps)

*All Wave 0 files are net-new — no existing infrastructure to reuse.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| GPU passthrough (nvidia-container-toolkit) | OLLAMA-02 | CI runners have no GPU | On a machine with `nvidia-container-toolkit`, run `docker run --gpus all ghcr.io/.../ollama-models:latest`; verify `nvidia-smi` visible inside and `/api/tags` responds |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s (local smoke)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
