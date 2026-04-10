# Phase 6: Workspace Template - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Provide a copyable example workspace template that users can drop into their own project to run the air-gapped dev environment through the existing compose-first devcontainer flow. This phase packages the already-decided `.devcontainer/` and offline bundle workflow into a reusable onboarding artifact; it does not redesign the compose topology, export/import contract, or GHCR publication strategy.

</domain>

<decisions>
## Implementation Decisions

### Template packaging
- **D-01:** Ship a copyable example directory at `templates/workspace-template/` that contains the template `.devcontainer/` assets and any small helper files the copied workspace needs.
- **D-02:** The template should preserve the existing compose-first shape: `dev-env` as the primary service, `ollama` as the sidecar, `ai-net` as the network, and `/workspace` as the mounted workspace path.

### Image references and portability
- **D-03:** Keep the runnable template override-friendly through environment-driven image references instead of hard-coded edits in the YAML.
- **D-04:** Document explicit GHCR version/tag examples inline so air-gapped operators know what to pin for reproducible deployments.
- **D-05:** The default copy/paste path must still work with the current local/offline import workflow without requiring users to rewrite service names or compose structure.

### Documentation location and style
- **D-06:** Put the full operator workflow inline as comments inside the template files instead of relying on a separate template README.
- **D-07:** Inline docs must cover the full path end-to-end: optional `cuda-prep`, export, transfer, import, `docker compose up`, and VS Code reopen-in-container.

### Fallback and GPU guidance
- **D-08:** Keep the base template CPU-safe and compose-internal by default, with `OLLAMA_HOST` defaulting to `http://ollama:11434`.
- **D-09:** Show the Windows host Ollama fallback and GPU usage as clearly labeled commented examples rather than active default config.

### Copy/paste experience
- **D-10:** Optimize for the default operator flow: copy the template into a new repo, run `docker compose up`, then reopen in container with no required edits.

### OpenCode's Discretion
- Exact comment density and file layout inside the template, as long as the workflow remains self-contained and readable.
- Whether to include a tiny helper example such as `.env.example` if it materially improves copy/paste clarity without turning the template into a larger framework.

</decisions>

<specifics>
## Specific Ideas

- The template should feel like a standalone reference artifact, not a partial snippet that forces the user back into the main repo docs.
- Comments should explain both the default compose-internal Ollama path and the host-override path without making the host fallback feel like the primary mode.
- Reuse the already-stable command surface from `cuda-prep.*`, `image-export.*`, and `image-import.*` so operators see one consistent workflow across the repo and the template.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Workspace Template - TMPL-01 and TMPL-02 define the phase acceptance criteria.
- `.planning/ROADMAP.md` §Phase 6: Workspace Template - goal, success criteria, and inline-documentation requirements.

### Prior phase outputs
- `.planning/phases/02-compose-stack/02-CONTEXT.md` - locked compose service names, network naming, endpoint defaults, and override strategy.
- `.planning/phases/03-devcontainer-integration/03-CONTEXT.md` - locked devcontainer handoff, workspace path, and service wiring.
- `.planning/phases/04-export-scripts-cuda-prep/04-CONTEXT.md` - export contract and required operator workflow language.
- `.planning/phases/05-import-scripts/05-CONTEXT.md` - import contract, compose validation path, and CUDA payload behavior.

### Current code and docs
- `.devcontainer/docker-compose.yml` - current source of truth for the compose stack the template should mirror.
- `.devcontainer/devcontainer.json` - current source of truth for the compose-based VS Code attachment flow.
- `.devcontainer/configure-ollama-endpoint.sh` - existing helper that keeps Pi/OpenCode aligned with `OLLAMA_HOST`.
- `README.md` §Transport Archive Workflow and §Deploying to an Air-Gapped Machine - existing operator wording for export/import/CUDA flow that the inline template comments should stay consistent with.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.devcontainer/docker-compose.yml`: already defines the exact service names, environment defaults, health-gated startup, named volumes, and `ai-net` contract the template should mirror.
- `.devcontainer/devcontainer.json`: already defines the minimal compose-based devcontainer contract (`dockerComposeFile`, `service`, `runServices`, `workspaceFolder`, `workspaceMount`, `remoteUser`).
- `.devcontainer/configure-ollama-endpoint.sh`: already rewrites Pi and OpenCode config to follow the effective `OLLAMA_HOST`, so the template can stay aligned with existing runtime behavior.
- `image-export.sh`, `image-export.ps1`, `image-import.sh`, `image-import.ps1`, `cuda-prep.sh`, and `cuda-prep.ps1`: provide the existing command surface that the template comments should reference directly.

### Established Patterns
- The repo prefers minimal, explicit config files and small helper scripts over extra abstraction layers.
- Operator-facing shell scripts use clear fail-fast behavior and explicit command examples; the template comments should match that tone.
- Current compose defaults are local-image-friendly (`dotfiles-dev-env:local`, `ollama/ollama:0.20.3`) while still supporting override-based pinning.

### Integration Points
- The Phase 6 template should be the main onboarding artifact for new projects that want this stack without copying unrelated dotfiles.
- Any template file introduced here should stay structurally aligned with `.devcontainer/` so future compose or import/export changes can be mirrored with minimal drift.

</code_context>

<deferred>
## Deferred Ideas

- Turning the template into a generalized scaffolding tool or installer.
- Adding multiple template variants for separate GPU, host-Ollama, or Podman-first modes.
- Reworking Phase 1 image publication or the current local-image fallback as part of template work.

</deferred>

---

*Phase: 06-workspace-template*
*Context gathered: 2026-04-10*
