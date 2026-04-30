---
phase: 6
slug: workspace-template
status: current
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-10
updated: 2026-04-10T15:36:11Z
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for the copyable workspace template and its drift checks.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash syntax checks, JSON assertions, and focused template drift tests |
| **Config files** | `templates/workspace-template/.devcontainer/*`, `templates/workspace-template/.env.example` |
| **Quick run command** | `bash -n templates/workspace-template/.devcontainer/configure-ollama-endpoint.sh` |
| **Full suite command** | `bash tests/container/test_workspace_template.sh` |
| **Estimated runtime** | < 1 min |

---

## Sampling Rate

- **After every template edit:** Re-run the focused workspace-template test
- **After every root compose/devcontainer contract change:** Re-check that the template still mirrors `dev-env`, `ollama`, `ai-net`, and `/workspace`
- **Before milestone verification:** Confirm the inline comments still cover `cuda-prep`, export, transfer, import, compose startup, and VS Code reopen
- **Max feedback latency:** < 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 6-01 | 01 | 1 | TMPL-01 | Template is copyable and preserves the production stack contract | Structural | `bash tests/container/test_workspace_template.sh` | ✅ | ✅ green |
| 6-02 | 01 | 1 | TMPL-02 | Inline docs cover the full operator workflow and optional overrides | Structural | `grep -q 'cuda-prep' templates/workspace-template/.devcontainer/docker-compose.yml && grep -q 'image-import' templates/workspace-template/.devcontainer/docker-compose.yml` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `templates/workspace-template/` exists with copyable `.devcontainer` assets and `.env.example`
- [x] Validation coverage exists for service names, workspace path, endpoint defaults, and inline workflow references
- [x] Template drift checks are wired into the repo test suite

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Copy the template into a fresh repo and run the default path end-to-end | TMPL-01, TMPL-02 | Requires a second workspace and live container runtime | Copy `templates/workspace-template/` into a new repo, run `docker compose up -d`, then reopen in VS Code |

---

## Validation Sign-Off

- [x] All requirements have automated structural coverage or an explicit manual-only gate
- [x] Sampling continuity is preserved
- [x] Wave 0 coverage is complete
- [x] No watch-mode steps are required
- [x] Fast feedback is available in under 300 seconds
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved for static verification; fresh-repo copy/paste runtime remains a human follow-up scenario
