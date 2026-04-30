---
phase: 3
slug: devcontainer-integration
status: current
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-10
updated: 2026-04-10T15:36:11Z
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for the compose-backed devcontainer entrypoint.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | JSON assertions, `devcontainer read-configuration`, and static container config checks |
| **Config file** | `.devcontainer/devcontainer.json` |
| **Quick run command** | `python3 -c 'import json; d=json.load(open(".devcontainer/devcontainer.json")); ...'` |
| **Full suite command** | `devcontainer read-configuration --workspace-folder . >/dev/null && bash tests/container/test_configs.sh` |
| **Estimated runtime** | < 1 min |

---

## Sampling Rate

- **After every devcontainer edit:** Re-run JSON assertions on `dockerComposeFile`, `service`, `runServices`, `workspaceFolder`, `workspaceMount`, and `remoteUser`
- **After every contract change:** Re-run `devcontainer read-configuration --workspace-folder . >/dev/null`
- **Before milestone verification:** Re-run the static config suite and separate unrelated baseline failures from Phase 3 contract checks
- **Max feedback latency:** < 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 3-01 | 01 | 1 | DEV-01 | Devcontainer uses compose mode rooted in `.devcontainer/` | Structural | `python3 -c 'import json; d=json.load(open(".devcontainer/devcontainer.json")); assert d["dockerComposeFile"] in ("docker-compose.yml", ["docker-compose.yml"])'` | ✅ | ✅ green |
| 3-02 | 01 | 1 | DEV-02 | VS Code attaches to `dev-env`, keeps `/workspace`, and uses remote user `dev` | Structural | `python3 -c 'import json; d=json.load(open(".devcontainer/devcontainer.json")); assert d["service"]=="dev-env"; assert d["workspaceFolder"]=="/workspace"; assert d["workspaceMount"].startswith("source=${localWorkspaceFolder},target=/workspace,type=bind"); assert d["remoteUser"]=="dev"'` | ✅ | ✅ green |
| 3-03 | 01 | 1 | DEV-03 | Both `dev-env` and `ollama` start through `runServices` | Structural | `python3 -c 'import json; d=json.load(open(".devcontainer/devcontainer.json")); assert d["runServices"]==["dev-env","ollama"]' && devcontainer read-configuration --workspace-folder . >/dev/null` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `.devcontainer/devcontainer.json` exists
- [x] Validation coverage exists for compose mode, target service, workspace contract, remote user, and `runServices`
- [x] Devcontainer CLI can parse the configuration in this workspace

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| VS Code "Reopen in Container" starts both services and attaches to `dev-env` | DEV-01, DEV-02, DEV-03 | Requires editor-driven container startup outside this workspace automation | Open the repo in VS Code, choose "Reopen in Container", then confirm both services are running and the workspace is mounted at `/workspace` |
| Pi/OpenCode end-to-end inference from inside the reopened container | DEV-03 | Requires a live reopened devcontainer with reachable Ollama | From inside the reopened container, run a minimal Pi/OpenCode request against the configured Ollama endpoint |

---

## Validation Sign-Off

- [x] All requirements have automated structural coverage or an explicit manual-only gate
- [x] Sampling continuity is preserved
- [x] Wave 0 coverage is complete
- [x] No watch-mode steps are required
- [x] Fast feedback is available in under 300 seconds
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved for static verification; full editor reopen remains a human follow-up scenario
