---
phase: 01-ollama-image
verified: 2026-04-09T22:25:00Z
status: human_needed
score: 8/8 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run docker run ghcr.io/.../ollama-models:latest and call GET /api/tags — confirm both gemma4:26b and gemma4:e4b appear in the JSON response with no internet access"
    expected: "JSON response lists both gemma4:26b and gemma4:e4b model entries"
    why_human: "Cannot pull or run the image locally; requires a live Docker environment with build access. Verifies OLLAMA-01 end-to-end."
  - test: "Run the built container WITHOUT --gpus flag and confirm the /api/tags endpoint responds successfully"
    expected: "Server starts and responds on CPU without error"
    why_human: "CPU fallback behavior can only be confirmed by actually running the container. Dockerfile has no GPU directives (verified), but runtime behavior requires execution."
  - test: "Trigger build-ollama.yml manually via workflow_dispatch in GitHub Actions UI"
    expected: "lint and build-and-test complete; both gemma4 models are confirmed in the validate step; GHCR push steps are skipped because this is not a master push"
    why_human: "CI execution cannot be simulated locally. Verifies OLLAMA-04 workflow integration."
  - test: "Push a change to Dockerfile.ollama on master and confirm both :latest and :sha-{7char} tags appear in GHCR packages"
    expected: "The master-push run completes and both tags are visible at ghcr.io/ldj-share/.dotfiles/ollama-models"
    why_human: "GHCR publication requires a real master push through CI. The workflow now promotes the already-tested local image and must be confirmed live."
---

# Phase 1: Ollama Image Verification Report

**Phase Goal:** Build and publish a pre-baked Ollama container image containing gemma4:26b and gemma4:e4b models, with GPU/CPU detection, ready for compose integration.
**Verified:** 2026-04-09T22:25:00Z
**Status:** human_needed
**Re-verification:** Yes — refreshed after Phase 1 review fixes

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A container built from Dockerfile.ollama contains both gemma4:26b and gemma4:e4b model blobs | ✓ VERIFIED | Two separate `RUN` layers start Ollama on `127.0.0.1:11235` and call `ollama pull gemma4:26b` / `ollama pull gemma4:e4b` |
| 2 | The built image exposes Ollama on 0.0.0.0:11434 (not 127.0.0.1) | ✓ VERIFIED | `ENV OLLAMA_HOST=0.0.0.0:11434` and `EXPOSE 11434` are present after both pull layers |
| 3 | The image starts and serves /api/tags without any internet access after build | ✓ VERIFIED (structure) | Models are baked into build layers; runtime only serves local model data. Live execution still requires human verification. |
| 4 | GPU/CPU fallback requires no Dockerfile changes — runtime detection only | ✓ VERIFIED | No GPU directives, `device_requests`, or `--gpus` configuration appear in Dockerfile.ollama |
| 5 | The Dockerfile HEALTHCHECK uses curl (installed in the image) to probe /api/tags | ✓ VERIFIED | `apt-get install -y -qq curl` and `HEALTHCHECK ... curl -sf http://localhost:11434/api/tags` are both present |
| 6 | Pushing to master triggers the workflow only when Dockerfile.ollama or build-ollama.yml changes | ✓ VERIFIED | `on.push.paths` is scoped to `Dockerfile.ollama` and `.github/workflows/build-ollama.yml` |
| 7 | The build-and-test job verifies both gemma4 models are present in the built image and fails clearly if Ollama never becomes ready | ✓ VERIFIED | The validate step polls `/api/tags`, aborts explicitly after 30 failed attempts, then checks for both model IDs |
| 8 | On master pushes, the workflow publishes both :latest and :sha-{7char} tags by retagging the already-tested `ollama-models:ci` image | ✓ VERIFIED | Conditional GHCR login, owner/SHA setup, retag, and `docker push` steps all operate on `ollama-models:ci` in the same job |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Dockerfile.ollama` | Pre-baked Ollama image with gemma4:26b and gemma4:e4b | VERIFIED | Pinned base image, curl install, two model RUN layers, cleanup traps, runtime bind, and HEALTHCHECK present |
| `.github/workflows/build-ollama.yml` | CI workflow that builds, validates, and publishes the Ollama image to GHCR | VERIFIED | Path-scoped triggers, two jobs (`lint`, `build-and-test`), validation gate, pinned disk-space action, and conditional GHCR publish steps |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Dockerfile.ollama RUN layers | `/usr/share/ollama/.ollama/models` | `ollama pull` inside background-serve loop on `127.0.0.1:11235` | VERIFIED | Both model pull patterns are present in separate RUN layers |
| ENV directive | container runtime | `ENV OLLAMA_HOST=0.0.0.0:11434` | VERIFIED | Runtime bind appears after the final model-pull layer |
| build-and-test validation | GHCR push steps | shared local image tag `ollama-models:ci` | VERIFIED | The image under test is the exact image retagged and pushed on master runs |
| conditional push steps | `ghcr.io/ldj-share/.dotfiles/ollama-models` | `docker tag` + `docker push` | VERIFIED | Both `:latest` and `:sha-${SHORT_SHA}` tags are pushed from the tested image |

### Data-Flow Trace (Level 4)

Not applicable — artifacts are a Dockerfile and a CI workflow, not components rendering dynamic data.

### Behavioral Spot-Checks

Step 7b: SKIPPED — actual build, run, and publish behavior requires a live Docker environment and GitHub Actions runner. Human verification covers those runtime and CI checks.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| OLLAMA-01 | 01-01-PLAN.md | Ollama container image pre-baked with gemma4:26b and gemma4:e4b, published to GHCR | SATISFIED (structure) | Dockerfile.ollama pulls both models at build time; workflow publishes on master push after validation |
| OLLAMA-02 | 01-01-PLAN.md | NVIDIA GPU passthrough when available; degrades to CPU | SATISFIED | Dockerfile stays runtime-agnostic; GPU enablement remains a Phase 2 runtime concern |
| OLLAMA-03 | 01-01-PLAN.md | OLLAMA_HOST bound to 0.0.0.0:11434 | SATISFIED | Runtime ENV binding is present after both model pull layers |
| OLLAMA-04 | 01-02-PLAN.md | GitHub Actions workflow builds and publishes on changes | SATISFIED (structure) | `build-ollama.yml` validates the image first, then conditionally retags and pushes the tested image on master pushes |

No orphaned requirements — all four Phase 1 requirement IDs (OLLAMA-01 through OLLAMA-04) are claimed by plans and verified above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | — |

No TODOs, FIXMEs, placeholder text, empty implementations, or stub patterns found in either artifact.

### Human Verification Required

#### 1. End-to-End Model Presence Check (OLLAMA-01)

**Test:** Pull and run `docker run -d -p 11434:11434 ghcr.io/ldj-share/.dotfiles/ollama-models:latest`, wait for the health check to pass, then call `curl http://localhost:11434/api/tags`.
**Expected:** JSON response contains entries for both `gemma4:26b` and `gemma4:e4b` with no outbound internet calls after image pull.
**Why human:** Cannot execute a live container run locally.

#### 2. CPU-Only Startup Fallback (OLLAMA-02)

**Test:** Start the container on a machine without NVIDIA hardware or without `--gpus`: `docker run --rm -p 11434:11434 ghcr.io/ldj-share/.dotfiles/ollama-models:latest`.
**Expected:** Ollama starts successfully, the health check passes, and `/api/tags` returns both models.
**Why human:** CPU fallback behavior requires a live container runtime.

#### 3. CI Workflow Integration (OLLAMA-04 — workflow_dispatch)

**Test:** Trigger `build-ollama.yml` manually in GitHub Actions.
**Expected:** `lint` passes, `build-and-test` validates both models, and the GHCR publish steps are skipped because the run is not a master push.
**Why human:** GitHub Actions execution cannot be simulated locally.

#### 4. GHCR Publish On Master Push (OLLAMA-04 — publish)

**Test:** Merge a change that touches `Dockerfile.ollama` or `build-ollama.yml` to master and observe the CI run.
**Expected:** The master-push run completes and both `ghcr.io/ldj-share/.dotfiles/ollama-models:latest` and `ghcr.io/ldj-share/.dotfiles/ollama-models:sha-{7char}` appear in GHCR.
**Why human:** Requires a real master push and GHCR access.

### Gaps Summary

No structural gaps remain. The Phase 1 artifacts are implemented, the earlier review issues are resolved, and the workflow now promotes the already-tested image instead of rebuilding for publish.

The remaining work is live runtime and CI confirmation only.

---

_Verified: 2026-04-09T22:25:00Z_
_Verifier: Claude (gsd-verifier refresh)_
