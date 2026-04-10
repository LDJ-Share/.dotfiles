---
phase: 01-ollama-image
verified: 2026-04-10T03:54:56Z
status: blocked
score: 6/8 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run the image from a successful manual build or staging-machine export and call GET /api/tags — confirm both gemma4:26b and gemma4:e4b appear in the JSON response with no internet access"
    expected: "JSON response lists both gemma4:26b and gemma4:e4b model entries"
    why_human: "Cannot pull or run the image locally; requires a live Docker environment with build access. Verifies OLLAMA-01 end-to-end."
  - test: "Run the built container WITHOUT --gpus flag and confirm the /api/tags endpoint responds successfully"
    expected: "Server starts and responds on CPU without error"
    why_human: "CPU fallback behavior can only be confirmed by actually running the container. Dockerfile has no GPU directives (verified), but runtime behavior requires execution."
  - test: "Trigger build-ollama.yml manually via workflow_dispatch in GitHub Actions UI after moving the build to larger or self-hosted capacity"
    expected: "lint and build-and-test complete; both gemma4 models are confirmed in the validate step; GHCR push steps are skipped because this is not a master push"
    why_human: "CI execution cannot be simulated locally, and the current GitHub-hosted runner path is already known-bad for this image size."
  - test: "Re-run the master publish path only after moving the build to larger or self-hosted capacity"
    expected: "The build completes, validation runs, and both GHCR tags are pushed"
    why_human: "Run `24223620363` proved the current GitHub-hosted runner path is blocked by disk exhaustion before validation or publish."
---

# Phase 1: Ollama Image Verification Report

**Phase Goal:** Build and publish a pre-baked Ollama container image containing gemma4:26b and gemma4:e4b models, with GPU/CPU detection, ready for compose integration.
**Verified:** 2026-04-10T03:54:56Z
**Status:** blocked
**Re-verification:** Yes — refreshed after the failed master run established a hosted-runner disk blocker

## Blocker

Phase 1 is blocked for live publication on GitHub-hosted runners.

- Failed run: `24223620363` (`https://github.com/LDJ-Share/.dotfiles/actions/runs/24223620363`)
- Failing job/step: `Build and Test` -> `Build image`
- Disk evidence before the failure: `Maximize build disk space` reported `/dev/root 145G 145G 100M 100% /` while the workspace mount had free space elsewhere
- Terminal failure: `failed to copy: write /var/lib/docker/buildkit/content/ingest/.../data: no space left on device`
- Outcome: validation and GHCR push steps were skipped because the image never built

Manual model pull on a connected staging machine is an acceptable fallback for now, so downstream compose/devcontainer work can continue.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A container built from Dockerfile.ollama contains both gemma4:26b and gemma4:e4b model blobs | ✓ VERIFIED | Two separate `RUN` layers start Ollama on `127.0.0.1:11235` and call `ollama pull gemma4:26b` / `ollama pull gemma4:e4b` |
| 2 | The built image exposes Ollama on 0.0.0.0:11434 (not 127.0.0.1) | ✓ VERIFIED | `ENV OLLAMA_HOST=0.0.0.0:11434` and `EXPOSE 11434` are present after both pull layers |
| 3 | The image starts and serves /api/tags without any internet access after build | PENDING | Models are baked into build layers structurally, but no successful live build artifact is available from CI yet. |
| 4 | GPU/CPU fallback requires no Dockerfile changes — runtime detection only | ✓ VERIFIED | No GPU directives, `device_requests`, or `--gpus` configuration appear in Dockerfile.ollama |
| 5 | The Dockerfile HEALTHCHECK uses curl (installed in the image) to probe /api/tags | ✓ VERIFIED | `apt-get install -y -qq curl` and `HEALTHCHECK ... curl -sf http://localhost:11434/api/tags` are both present |
| 6 | Pushing to master triggers the workflow only when Dockerfile.ollama or build-ollama.yml changes | ✓ VERIFIED | `on.push.paths` is scoped to `Dockerfile.ollama` and `.github/workflows/build-ollama.yml` |
| 7 | The build-and-test job verifies both gemma4 models are present in the built image and fails clearly if Ollama never becomes ready | ✓ VERIFIED | The validate step polls `/api/tags`, aborts explicitly after 30 failed attempts, then checks for both model IDs |
| 8 | On master pushes, the workflow publishes both :latest and :sha-{7char} tags by retagging the already-tested `ollama-models:ci` image | BLOCKED | Workflow structure is correct, but run `24223620363` failed before validation and publish with `/var/lib/docker/buildkit/...: no space left on device` |

**Score:** 6/8 truths verified, 1 pending live runtime check, 1 blocked by hosted-runner disk limits

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
| build-and-test validation | GHCR push steps | shared local image tag `ollama-models:ci` | VERIFIED (structure) | The workflow is wired so the image under test is the same image retagged for publish when the build succeeds |
| conditional push steps | `ghcr.io/ldj-share/.dotfiles/ollama-models` | `docker tag` + `docker push` | VERIFIED (structure) | Both `:latest` and `:sha-${SHORT_SHA}` tag push steps are present, but live publish is currently blocked by runner disk limits |

### Data-Flow Trace (Level 4)

Not applicable — artifacts are a Dockerfile and a CI workflow, not components rendering dynamic data.

### Behavioral Spot-Checks

Step 7b: SKIPPED — actual build, run, and publish behavior requires a live Docker environment and GitHub Actions runner. Human verification covers those runtime and CI checks.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| OLLAMA-01 | 01-01-PLAN.md | Ollama container image pre-baked with gemma4:26b and gemma4:e4b, published to GHCR | PARTIAL | Dockerfile.ollama pulls both models at build time, but no published GHCR image exists yet because the hosted-runner build path is blocked |
| OLLAMA-02 | 01-01-PLAN.md | NVIDIA GPU passthrough when available; degrades to CPU | SATISFIED | Dockerfile stays runtime-agnostic; GPU enablement remains a Phase 2 runtime concern |
| OLLAMA-03 | 01-01-PLAN.md | OLLAMA_HOST bound to 0.0.0.0:11434 | SATISFIED | Runtime ENV binding is present after both model pull layers |
| OLLAMA-04 | 01-02-PLAN.md | GitHub Actions workflow builds and publishes on changes | BLOCKED | `build-ollama.yml` is implemented, but master run `24223620363` failed before validation/publish with `failed to copy ... no space left on device` |

No orphaned requirements — all four Phase 1 requirement IDs (OLLAMA-01 through OLLAMA-04) are claimed by plans and verified above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | — |

No TODOs, FIXMEs, placeholder text, empty implementations, or stub patterns found in either artifact.

### Human Verification Required

#### 1. End-to-End Model Presence Check (OLLAMA-01)

**Test:** Run the image from a successful manual build or staging-machine export, wait for the health check to pass, then call `curl http://localhost:11434/api/tags`.
**Expected:** JSON response contains entries for both `gemma4:26b` and `gemma4:e4b` with no outbound internet calls after image pull.
**Why human:** Cannot execute a live container run locally.

#### 2. CPU-Only Startup Fallback (OLLAMA-02)

**Test:** Start the successfully built or manually prepared container on a machine without NVIDIA hardware or without `--gpus`: `docker run --rm -p 11434:11434 <local-or-staging-built-ollama-image>`.
**Expected:** Ollama starts successfully, the health check passes, and `/api/tags` returns both models.
**Why human:** CPU fallback behavior requires a live container runtime.

#### 3. CI Workflow Integration (OLLAMA-04 — workflow_dispatch)

**Test:** Trigger `build-ollama.yml` manually in GitHub Actions after moving the build to larger or self-hosted capacity.
**Expected:** `lint` passes, `build-and-test` validates both models, and the GHCR publish steps are skipped because the run is not a master push.
**Why human:** GitHub Actions execution cannot be simulated locally.

#### 4. GHCR Publish On Master Push (OLLAMA-04 — publish)

**Test:** Re-run only after moving the workflow to larger or self-hosted build capacity.
**Expected:** The build completes, validation runs, and both `ghcr.io/ldj-share/.dotfiles/ollama-models:latest` and `ghcr.io/ldj-share/.dotfiles/ollama-models:sha-{7char}` appear in GHCR.
**Why human:** Current GitHub-hosted capacity is known-bad from run `24223620363`.

### Gaps Summary

No structural gaps remain in the Phase 1 code artifacts.

The blocking gap is execution environment capacity: GitHub-hosted runners do not currently provide enough root-disk headroom for this image path. Phase 2 can continue by treating manual model pull on a connected staging machine as an acceptable fallback until the publish path moves to larger or self-hosted capacity.

---

_Verified: 2026-04-10T03:54:56Z_
_Verifier: Claude (gsd-verifier refresh)_
