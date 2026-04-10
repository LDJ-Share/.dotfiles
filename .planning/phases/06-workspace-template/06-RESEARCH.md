# Phase 6: Workspace Template - Research

**Researched:** 2026-04-10
**Domain:** Copyable devcontainer templates, compose-backed workspace onboarding, inline operator documentation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 / D-02:** Ship a copyable example directory at `templates/workspace-template/` and preserve the existing compose-first shape (`dev-env`, `ollama`, `ai-net`, `/workspace`).
- **D-03 / D-05:** Keep the template runnable through environment-driven image references so the current local/offline import path still works without YAML rewrites.
- **D-04:** Document explicit GHCR tag examples inline so reproducible pinning is obvious.
- **D-06 / D-07:** Put the full operator workflow inline as comments in the template files and cover the end-to-end air-gap path (`cuda-prep` -> export -> transfer -> import -> compose -> reopen in container).
- **D-08 / D-09:** Keep the default path CPU-safe and compose-internal; show host-Ollama fallback and GPU handling as commented examples, not active defaults.
- **D-10:** Optimize for copy -> `docker compose up` -> reopen in container with no required edits.

### OpenCode's Discretion

- Exact file layout inside the template directory
- Whether a tiny helper like `.env.example` improves clarity enough to justify one extra file

### Deferred Ideas (OUT OF SCOPE)

- Template generators or scaffolding CLIs
- Multiple template variants for different runtimes or deployment modes
- Reworking Phase 1 image publication strategy during template work
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TMPL-01 | Example workspace template (`.devcontainer/` + `docker-compose.yml`) provided for users to copy into their own project | Template directory structure, mirrored compose/devcontainer assets, copyable defaults |
| TMPL-02 | Template includes inline documentation covering the full air-gap workflow | Comment strategy inside template files, direct references to export/import/CUDA commands, fallback examples |
</phase_requirements>

---

## Summary

The strongest Phase 6 approach is to treat the current `.devcontainer/` assets as the canonical implementation and package a trimmed, commented copy under `templates/workspace-template/`. That keeps the template aligned with the production compose/devcontainer contract while avoiding a second independently-designed stack.

The key planning tension is between copyability and drift control. A standalone template must be readable on its own, but it should not fork behavior from `.devcontainer/docker-compose.yml`, `.devcontainer/devcontainer.json`, or the current import/export scripts. The best compromise is to mirror those files closely, add only targeted inline comments, and cover overrides through environment variables plus commented examples rather than separate active variants.

Inline documentation belongs inside the template files because TMPL-02 explicitly wants the template to function as the primary onboarding artifact. The comments should explain the default compose-internal Ollama path, the optional Windows host fallback, the optional GPU overlay/example, and the exact offline transport commands already established by `cuda-prep.*`, `image-export.*`, and `image-import.*`. Reusing those existing command surfaces avoids inventing a competing workflow just for the template.

**Primary recommendation:** create `templates/workspace-template/.devcontainer/` with a compose file, devcontainer file, and any tiny support file it genuinely needs; keep image references env-driven; add concise but complete inline comments; and add a focused static test that verifies the template still mirrors the production service names, workspace path, and key environment defaults.

---

## Standard Stack

### Core

| File / Pattern | Source of Truth | Why It Should Be Reused |
|----------------|-----------------|--------------------------|
| `.devcontainer/docker-compose.yml` | Current repo compose contract | Already defines service names, network, volumes, health check, and `OLLAMA_HOST` default |
| `.devcontainer/devcontainer.json` | Current repo VS Code contract | Already encodes compose startup, service attachment, and `/workspace` mount rules |
| `.devcontainer/configure-ollama-endpoint.sh` | Current repo runtime helper | Already rewrites Pi/OpenCode config to match the effective endpoint |
| `image-export.*`, `image-import.*`, `cuda-prep.*` | Current repo operator workflow | Already define the transport/import contract the template should document |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `templates/workspace-template/` | Reuse the root `.devcontainer/` directly as the template | Easier initially, but not copyable into other repos without dragging unrelated project files along |
| Inline comments in template files | Separate template README only | Easier to write, but violates the requirement that the template itself be the onboarding artifact |
| Env-driven image refs | Hard-coded GHCR tags in YAML | More reproducible by default, but worse for the current local/offline import workflow and less override-friendly |

---

## Architecture Patterns

### Pattern 1: Mirror-Not-Reinvent Template Files

Keep the template structurally close to the production `.devcontainer/` files. This reduces drift and keeps service names, workspace mount paths, and health-gated startup consistent.

**Use when:** The repo already has a working compose/devcontainer setup and the template is meant to onboard users into that exact workflow.

### Pattern 2: Comments as Operator Runbook

Put the critical workflow steps directly in the template files as short, skimmable comments near the configuration they explain. For example: image override examples live near `image:`, host fallback lives near `OLLAMA_HOST`, and VS Code reopen guidance lives in `devcontainer.json`.

**Use when:** Operators may copy the template into an isolated project and should not need to cross-reference another document to understand the happy path.

### Pattern 3: Default-Safe, Override-Friendly Config

Keep the active configuration minimal and safe for CPU + compose-internal Ollama, then add commented examples for GHCR pinning, host fallback, and GPU enablement.

**Use when:** The template must work out of the box while still documenting alternative deployment modes without turning them into the default.

### Pattern 4: Static Drift Checks

Add a lightweight test that checks the template still contains the required service names, `OLLAMA_HOST` default, workspace path, and devcontainer contract. This is enough to catch accidental divergence without requiring full template execution in CI.

**Use when:** The template is documentation-heavy but still needs guardrails against config drift.

---

## Planning Implications

- One execution plan is sufficient: create the template files, add inline comments, and add a focused validation test/doc touch-up in the same wave.
- The plan should explicitly avoid redesigning the current `.devcontainer/` stack. The template mirrors it; it does not supersede it.
- The plan should include verification that the template can be copied without required edits in the default path and that the inline docs mention all required workflow steps.

---

## Risks and Mitigations

| Risk | Why It Matters | Mitigation |
|------|----------------|------------|
| Template drifts from production `.devcontainer/` behavior | Users copy stale config into new repos | Mirror current files closely and add static drift tests |
| Comments overwhelm the template | Copyable files become noisy or confusing | Keep comments near the relevant config and prefer short operator notes over long prose blocks |
| GHCR publication is still blocked | Hard-coded published tags would make the template misleading today | Use env-driven defaults and show GHCR pins as commented examples |
| Host fallback becomes treated as the main path again | Undercuts compose-first architecture | Keep compose-internal Ollama as the active default and document host fallback as optional |

---

**Recommended planning stance:** create a single implementation plan centered on a mirrored, heavily-commented template directory plus static validation coverage.
