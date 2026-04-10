# Phase 3: Devcontainer Integration - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Switch `.devcontainer/devcontainer.json` from single-image mode to compose mode so VS Code opens the `dev-env` service while also starting the `ollama` sidecar. This phase wires the existing compose stack into the devcontainer workflow; it does not change the compose topology itself or add export/import automation.

</domain>

<decisions>
## Implementation Decisions

### Compose handoff
- **D-01:** `devcontainer.json` must reference the existing `.devcontainer/docker-compose.yml` file directly.
- **D-02:** The primary service is `dev-env`; `runServices` must include both `dev-env` and `ollama` so VS Code starts the full stack.

### Workspace alignment
- **D-03:** Keep `workspaceFolder` at `/workspace` and `remoteUser` at `dev` to match the image and current workflow.
- **D-04:** Keep an explicit `workspaceMount` targeting `/workspace` so VS Code mount behavior stays aligned with the compose bind mount.

### Scope discipline
- **D-05:** Phase 3 only changes devcontainer integration points and any tests/docs needed to validate that integration.
- **D-06:** Do not redesign `.devcontainer/docker-compose.yml` here unless a concrete devcontainer compatibility issue is discovered during implementation.

### Verification focus
- **D-07:** Validation should prove that `devcontainer.json` is valid JSON and encodes the compose workflow fields required by DEV-01 through DEV-03.
- **D-08:** If local tooling allows it, prefer a non-interactive `devcontainer` CLI config/readiness check in addition to static JSON verification.

### OpenCode's Discretion
- Whether to add a small targeted test script or extend an existing container/config test to cover the devcontainer contract.
- Whether to use a single string or single-item array for `dockerComposeFile`, as long as path resolution is unambiguous from `.devcontainer/`.

</decisions>

<specifics>
## Specific Ideas

- Keep the change minimal: the existing `workspaceFolder`, `workspaceMount`, and `remoteUser` values are already correct and should carry forward.
- The main risk is a quiet mismatch between VS Code's compose path resolution and the compose workspace mount target, so the plan should verify those exact fields.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Devcontainer — DEV-01 through DEV-03 define the acceptance criteria.
- `.planning/ROADMAP.md` §Phase 3: Devcontainer Integration — required fields, workspace mount note, and success criteria.

### Prior phase output
- `.planning/phases/02-compose-stack/02-CONTEXT.md` — decisions about compose file location, service names, and workspace path.
- `.planning/phases/02-compose-stack/02-01-SUMMARY.md` — confirms the compose stack is complete and ready for devcontainer handoff.

### Current code
- `.devcontainer/devcontainer.json` — current single-image baseline to replace with compose mode.
- `.devcontainer/docker-compose.yml` — canonical compose file that devcontainer.json must reference.
- `.devcontainer/configure-ollama-endpoint.sh` — startup behavior already wired into the `dev-env` compose service.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.devcontainer/docker-compose.yml` already defines the correct service names (`dev-env`, `ollama`), workspace bind mount, and health-gated startup.
- `README.md` already documents the repo's devcontainer workflow, so only targeted doc updates may be needed if the wording assumes image-only startup.

### Established Patterns
- `.devcontainer/devcontainer.json` is intentionally minimal today; Phase 3 should preserve that style and only add the fields required for compose mode.
- Planning research calls out a common failure mode where `workspaceFolder` and `workspaceMount` drift from the compose mount target.

### Integration Points
- Phase 4 export/import work will rely on the compose-first devcontainer path being stable.
- Any test coverage added here should be lightweight and static-first, since full VS Code reopen testing is not reliable in CI.

</code_context>

<deferred>
## Deferred Ideas

- Full end-to-end VS Code UI automation.
- Adding optional devcontainer features unrelated to compose startup.

</deferred>

---

*Phase: 03-devcontainer-integration*
*Context gathered: 2026-04-10*
