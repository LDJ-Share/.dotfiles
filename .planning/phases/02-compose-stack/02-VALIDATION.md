---
phase: 2
slug: compose-stack
status: current
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-10
updated: 2026-04-10T15:36:11Z
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for the compose-first stack and runtime endpoint bridge.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash checks, `docker compose config`, and temp-home config-rewrite verification |
| **Config files** | `.devcontainer/docker-compose.yml`, `.devcontainer/docker-compose.gpu.yml`, `.devcontainer/configure-ollama-endpoint.sh` |
| **Quick run command** | `docker compose -f .devcontainer/docker-compose.yml config >/dev/null && bash -n .devcontainer/configure-ollama-endpoint.sh` |
| **Full suite command** | `docker compose -f .devcontainer/docker-compose.yml config >/dev/null && bash tests/container/test_configs.sh` |
| **Estimated runtime** | < 1 min for structural checks |

---

## Sampling Rate

- **After every compose edit:** Re-run `docker compose -f .devcontainer/docker-compose.yml config >/dev/null`
- **After every endpoint-bridge edit:** Re-run `bash -n .devcontainer/configure-ollama-endpoint.sh` plus temp-home rewrite checks
- **Before milestone verification:** Confirm default and override URL rewrites for both Pi and OpenCode configs
- **Max feedback latency:** < 60 seconds for structural checks

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 2-01 | 01 | 1 | COMPOSE-01 | Base compose file defines `dev-env` and `ollama` on explicit `ai-net` | Structural | `docker compose -f .devcontainer/docker-compose.yml config >/dev/null && grep -q 'name: ai-net' .devcontainer/docker-compose.yml` | ✅ | ✅ green |
| 2-02 | 01 | 1 | COMPOSE-02 | Default endpoint stays `http://ollama:11434` inside the stack | Structural | `grep -q 'OLLAMA_HOST: \${OLLAMA_HOST:-http://ollama:11434}' .devcontainer/docker-compose.yml && grep -q 'ollama:11434/v1' dot-pi/models.json && grep -q 'ollama:11434/v1' dot-opencode/config.json` | ✅ | ✅ green |
| 2-03 | 01 | 1 | COMPOSE-03 | Override path rewrites tool configs from `OLLAMA_HOST` | Structural + Temp-home | `HOME="$TMPDIR" OLLAMA_HOST=10.10.10.10:11434 bash .devcontainer/configure-ollama-endpoint.sh` | ✅ | ✅ green |
| 2-04 | 01 | 1 | COMPOSE-04 | Compose remains Docker Compose v2 / Podman friendly | Structural | `grep -q '^x-podman:' .devcontainer/docker-compose.yml && test -f .devcontainer/docker-compose.gpu.yml` | ✅ | ✅ green |
| 2-05 | 01 | 1 | COMPOSE-05 | `dev-env` startup is gated on Ollama health | Structural | `grep -q 'condition: service_healthy' .devcontainer/docker-compose.yml && grep -q 'ollama ls' .devcontainer/docker-compose.yml` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `.devcontainer/docker-compose.yml` exists
- [x] `.devcontainer/docker-compose.gpu.yml` exists
- [x] `.devcontainer/configure-ollama-endpoint.sh` exists
- [x] Validation coverage exists for compose rendering, health-gated startup wiring, and endpoint override behavior

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full `docker compose up` startup with locally available images | COMPOSE-01, COMPOSE-05 | This workspace may not have both runtime images loaded locally | Run `docker compose -f .devcontainer/docker-compose.yml up -d` and confirm `dev-env` waits until Ollama is healthy |
| Podman compose startup | COMPOSE-04 | `podman compose` is not available in this workspace | Run `podman compose -f .devcontainer/docker-compose.yml up -d` on a Podman host and confirm both services start |

---

## Validation Sign-Off

- [x] All requirements have automated structural coverage or an explicit manual-only gate
- [x] Sampling continuity is preserved
- [x] Wave 0 coverage is complete
- [x] No watch-mode steps are required
- [x] Fast feedback is available in under 300 seconds
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved for static verification; live compose-up and Podman runtime checks remain human follow-up only
