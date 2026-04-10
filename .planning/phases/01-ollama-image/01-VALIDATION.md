---
phase: 1
slug: ollama-image
status: current
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-09
updated: 2026-04-09T22:30:00Z
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash checks plus `curl` smoke validation inside GitHub Actions |
| **Config file** | None — validation lives inline in `.github/workflows/build-ollama.yml` |
| **Quick run command** | `docker run --rm -p 11434:11434 ollama-models:ci` then `curl -sf http://localhost:11434/api/tags` |
| **Full suite command** | GitHub Actions `build-ollama.yml` run |
| **Estimated runtime** | ~30–40 min on cache miss; materially lower with cache hits |

---

## Sampling Rate

- **After every task edit:** Run file-level structural checks (`grep`, syntax checks, or workflow YAML parse)
- **After every workflow change:** Re-verify `/api/tags` validation logic and master-push publish gating
- **Before `/gsd-verify-work`:** Human-run CI and runtime checks must be green
- **Max feedback latency:** < 5 min for structural checks; ~40 min for full CI on cache miss

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01 | 01 | 1 | OLLAMA-01 | T-1-01 | Base image pinned to semver; both models baked into separate layers | Structural | `grep -q '^FROM ollama/ollama:0\.20\.3$' Dockerfile.ollama && grep -q 'ollama pull gemma4:26b' Dockerfile.ollama && grep -q 'ollama pull gemma4:e4b' Dockerfile.ollama` | ✅ | ✅ green |
| 1-02 | 01 | 1 | OLLAMA-02 | — | CPU fallback confirmed without GPU-only assumptions in image | Structural + Manual | `! grep -q 'device_requests\|--gpus' Dockerfile.ollama` | ✅ | ✅ green (manual runtime still pending) |
| 1-03 | 01 | 1 | OLLAMA-03 | — | Server bound to `0.0.0.0:11434` and health-checked via `/api/tags` | Structural | `grep -q 'ENV OLLAMA_HOST=0.0.0.0:11434' Dockerfile.ollama && grep -q 'HEALTHCHECK' Dockerfile.ollama` | ✅ | ✅ green |
| 1-04 | 02 | 1 | OLLAMA-04 | T-1-02 | Workflow validates before publish and publishes the tested image only | Structural | `grep -q 'easimon/maximize-build-space@v10' .github/workflows/build-ollama.yml && grep -q 'docker tag ollama-models:ci' .github/workflows/build-ollama.yml && grep -q 'docker push ghcr.io/' .github/workflows/build-ollama.yml` | ✅ | ✅ green (human CI run still pending) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `Dockerfile.ollama` exists
- [x] `.github/workflows/build-ollama.yml` exists
- [x] Validation coverage exists for both files even though there are no standalone test scripts in this phase

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CPU-only startup and `/api/tags` response | OLLAMA-01, OLLAMA-02 | Requires a live container runtime and built image | Run `docker run --rm -p 11434:11434 ghcr.io/.../ollama-models:latest` and call `curl http://localhost:11434/api/tags` |
| GPU passthrough with NVIDIA runtime | OLLAMA-02 | CI runners have no GPU | On a machine with `nvidia-container-toolkit`, run `docker run --gpus all ghcr.io/.../ollama-models:latest`; verify startup and `/api/tags` |
| GHCR publication on master push | OLLAMA-04 | Requires live GitHub Actions + GHCR | Push a qualifying change to master and confirm both tags appear in GHCR |

---

## Validation Sign-Off

- [x] All tasks have automated verification coverage or an explicit manual-only gate
- [x] Sampling continuity is preserved — no long gap without structural feedback
- [x] Wave 0 coverage is complete
- [x] No watch-mode flags
- [x] Fast structural feedback is available in under 300 seconds
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending live runtime and CI checks
