---
phase: 01-ollama-image
verified: 2026-04-09T17:15:00Z
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
  - test: "Trigger the build-ollama.yml workflow manually via workflow_dispatch in GitHub Actions UI"
    expected: "All three jobs (lint, build-and-test, publish) complete; publish job skipped because it is not a master push; both gemma4 models confirmed in the build-and-test validate step"
    why_human: "CI execution cannot be simulated locally. Verifies OLLAMA-04 workflow integration."
  - test: "Push a change to Dockerfile.ollama on master and confirm both :latest and :sha-{7char} tags appear in GHCR packages"
    expected: "Two new tags visible at ghcr.io/ldj-share/.dotfiles/ollama-models"
    why_human: "GHCR publish step requires a real master push through CI. The publish job logic is structurally correct but must be confirmed live."
---

# Phase 1: Ollama Image Verification Report

**Phase Goal:** Build and publish a pre-baked Ollama container image containing gemma4:26b and gemma4:e4b models, with GPU/CPU detection, ready for compose integration.
**Verified:** 2026-04-09T17:15:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A container built from Dockerfile.ollama contains both gemma4:26b and gemma4:e4b model blobs | ✓ VERIFIED | Two separate `RUN` layers each start ollama on `127.0.0.1:11235` and call `ollama pull gemma4:26b` / `ollama pull gemma4:e4b` (lines 44-74) |
| 2 | The built image exposes Ollama on 0.0.0.0:11434 (not 127.0.0.1) | ✓ VERIFIED | `ENV OLLAMA_HOST=0.0.0.0:11434` on line 82, after all pull layers; `EXPOSE 11434` on line 84 |
| 3 | The image starts and serves /api/tags without any internet access after build | ✓ VERIFIED (structure) | Models baked into RUN layers at build time; no network fetch at runtime. HEALTHCHECK probes `http://localhost:11434/api/tags`. Live execution requires human verification. |
| 4 | GPU/CPU fallback requires no Dockerfile changes — runtime detection only | ✓ VERIFIED | No GPU directives, no `device_requests`, no `--gpus` anywhere in Dockerfile.ollama. Comment on line 13-15 explicitly documents GPU is runtime/Phase 2. |
| 5 | The Dockerfile HEALTHCHECK uses curl (installed in the image) to probe /api/tags | ✓ VERIFIED | `apt-get install -y -qq curl` on line 34; `HEALTHCHECK ... CMD curl -sf http://localhost:11434/api/tags || exit 1` on lines 88-89 |
| 6 | Pushing to master triggers the workflow only when Dockerfile.ollama or build-ollama.yml changes | ✓ VERIFIED | `paths:` block in `on.push` lists exactly `Dockerfile.ollama` and `.github/workflows/build-ollama.yml` |
| 7 | The build-and-test job verifies both gemma4 models are present in the built image | ✓ VERIFIED | Validate step (lines 90-106) starts container, polls `/api/tags`, greps for both `gemma4:26b` and `gemma4:e4b`, exits 1 on failure |
| 8 | The publish job pushes both :latest and :sha-{7char} tags to ghcr.io/ldj-share/.dotfiles/ollama-models | ✓ VERIFIED | Lines 160-162: `ollama-models:latest` and `ollama-models:sha-${{ env.SHORT_SHA }}`; SHORT_SHA set via `${GITHUB_SHA::7}` |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Dockerfile.ollama` | Pre-baked Ollama image with gemma4:26b and gemma4:e4b | VERIFIED | 92 lines; pinned `FROM ollama/ollama:0.20.3`; curl installed; two RUN model layers; ENV after pulls; HEALTHCHECK present |
| `.github/workflows/build-ollama.yml` | CI workflow — build, test, and publish Ollama image to GHCR | VERIFIED | 169 lines; three jobs (lint, build-and-test, publish); full structure matches plan spec |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Dockerfile.ollama RUN layers | `/usr/share/ollama/.ollama/models` | `ollama pull` inside background-serve loop on `127.0.0.1:11235` | VERIFIED | Pattern `OLLAMA_HOST=127\.0\.0\.1:11235 ollama serve` confirmed on lines 44 and 63 |
| ENV directive | container runtime | `ENV OLLAMA_HOST=0.0.0.0:11434` | VERIFIED | Line 82; position confirmed after last pull (line 73) |
| build-and-test job | publish job | `needs: build-and-test` | VERIFIED | Line 114 of build-ollama.yml |
| publish job | `ghcr.io/ldj-share/.dotfiles/ollama-models` | `docker/build-push-action@v5 push: true` | VERIFIED | Lines 154-168; both tag formats present |

### Data-Flow Trace (Level 4)

Not applicable — artifacts are a Dockerfile and a CI workflow, not components rendering dynamic data.

### Behavioral Spot-Checks

Step 7b: SKIPPED — artifacts are a Dockerfile and CI workflow. No runnable entry points available locally; the actual build/test/publish loop requires a live Docker environment and GitHub Actions runner. Human verification covers these behaviors.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| OLLAMA-01 | 01-01-PLAN.md | Ollama container image pre-baked with gemma4:26b and gemma4:e4b, published to GHCR | SATISFIED (structure) | Dockerfile.ollama pulls both models at build time; GHCR publish handled by workflow. Runtime confirmation needs human CI run. |
| OLLAMA-02 | 01-01-PLAN.md | NVIDIA GPU passthrough when available; degrades to CPU | SATISFIED | No GPU directives in Dockerfile; runtime detection delegated to NVIDIA Container Toolkit at compose layer (Phase 2). Dockerfile comment documents this explicitly. |
| OLLAMA-03 | 01-01-PLAN.md | OLLAMA_HOST bound to 0.0.0.0:11434 | SATISFIED | `ENV OLLAMA_HOST=0.0.0.0:11434` present and positioned after all pull layers |
| OLLAMA-04 | 01-02-PLAN.md | GitHub Actions workflow builds and publishes on changes | SATISFIED (structure) | build-ollama.yml: path-scoped triggers, three jobs, GHCR push, both tags, YAML valid. Live execution needs human CI run. |

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
**Why human:** Cannot execute a live container run locally. This is the primary acceptance test for OLLAMA-01.

#### 2. CPU-Only Startup Fallback (OLLAMA-02)

**Test:** Start the container on a machine without NVIDIA hardware (or without `--gpus` flag): `docker run --rm -p 11434:11434 ghcr.io/ldj-share/.dotfiles/ollama-models:latest`.
**Expected:** Ollama server starts successfully, health check passes, `/api/tags` returns both models. No GPU errors, no crash.
**Why human:** CPU fallback behavior requires a live container runtime. Dockerfile structure confirms no GPU directives, but runtime behavior must be observed.

#### 3. CI Workflow Integration (OLLAMA-04 — workflow_dispatch)

**Test:** In GitHub Actions UI, navigate to `build-ollama.yml` and trigger `workflow_dispatch` manually.
**Expected:** lint job passes; build-and-test job builds the image and the validate step prints "PASS: Both models present in /api/tags"; publish job is skipped (not a master push).
**Why human:** GHA workflow execution cannot be simulated locally.

#### 4. GHCR Publish on Master Push (OLLAMA-04 — publish)

**Test:** Merge a change that touches `Dockerfile.ollama` to master and observe the CI run to completion.
**Expected:** publish job runs, both `ghcr.io/ldj-share/.dotfiles/ollama-models:latest` and `ghcr.io/ldj-share/.dotfiles/ollama-models:sha-{7char}` tags appear in GHCR packages.
**Why human:** Requires an actual master push through CI to verify the conditional publish job and GHCR authentication.

### Gaps Summary

No structural gaps found. Both artifacts exist, are fully implemented (not stubs), and are correctly wired. All acceptance criteria grep checks pass.

The four human verification items are standard CI/runtime checks that cannot be performed programmatically — they do not indicate missing or broken implementation. The structural code is complete and correct.

---

_Verified: 2026-04-09T17:15:00Z_
_Verifier: Claude (gsd-verifier)_
