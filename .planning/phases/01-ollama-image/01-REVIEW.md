---
phase: 01-ollama-image
reviewed: 2026-04-09T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - Dockerfile.ollama
  - .github/workflows/build-ollama.yml
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-04-09
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Both files are well-structured with clear documentation. The Dockerfile correctly pins the base image version, uses a non-default port for build-time server isolation, and cleans apt caches. The workflow uses scoped permissions and three-job separation. No critical security issues found.

Three warnings cover reliability gaps: a silent failure mode in the model-validation loop, an unpinned third-party action used in a privileged job, and a redundant full rebuild in the publish job that bypasses the tested artifact. Three info items cover minor code quality improvements.

## Warnings

### WR-01: Validate-models loop exits silently if server never starts

**File:** `.github/workflows/build-ollama.yml:97-104`
**Issue:** The readiness loop in "Validate models present" runs up to 30 iterations but has no failure branch if the loop exhausts without a successful `curl`. After the loop, `curl -sf http://localhost:11434/api/tags` is called unconditionally — if the server never came up, this call fails and its output is assigned to `TAGS` as an empty string. The subsequent `grep -q` checks then both fail, but the error messages say "model not found" rather than "server never started", making CI failures hard to diagnose. More critically, if `curl` exits non-zero but the shell swallows it due to command substitution, the `grep` checks may not even run correctly.

**Fix:** Add an explicit readiness check after the loop and fail fast with a clear message:
```bash
for i in $(seq 1 30); do
  curl -sf http://localhost:11434/api/tags >/dev/null 2>&1 && break
  echo "  attempt $i/30..."
  sleep 3
  if [ "$i" = "30" ]; then
    echo "FAIL: Ollama server did not become ready after 90s"
    docker stop ollama-ci
    exit 1
  fi
done
TAGS=$(curl -sf http://localhost:11434/api/tags)
```

---

### WR-02: Unpinned third-party action used in jobs with `packages: write`

**File:** `.github/workflows/build-ollama.yml:61,122`
**Issue:** `easimon/maximize-build-space@master` is pinned to the mutable `master` branch ref, not a commit SHA. This action runs in both `build-and-test` (packages: write) and `publish` (packages: write) jobs before checkout. A compromised or force-pushed `master` on that repo could inject arbitrary code into a job that has write access to GHCR. This is a supply chain risk.

**Fix:** Pin to the latest release commit SHA. Check `https://github.com/easimon/maximize-build-space/releases` for current release, then use:
```yaml
uses: easimon/maximize-build-space@v10  # or @<commit-sha>
```
Using a version tag (v10) is acceptable; using a full SHA is best practice for GHCR-publishing jobs.

---

### WR-03: Publish job rebuilds image from scratch instead of promoting tested artifact

**File:** `.github/workflows/build-ollama.yml:154-168`
**Issue:** The `publish` job runs `docker/build-push-action` independently of the `build-and-test` job. Even with GHA cache hits, this is a separate build invocation — the image that gets pushed to GHCR is not byte-for-byte the image that was validated in the test job. If cache misses occur (e.g., cache eviction under the 10GB GHA limit with 27GB+ of model data), the publish job will rebuild and re-pull models, potentially producing a different or incomplete image.

**Fix:** Export the tested image as a tarball artifact in `build-and-test`, then import and push it in `publish`:
```yaml
# In build-and-test:
- name: Save image as tarball
  run: docker save ollama-models:ci | gzip > ollama-models.tar.gz
- uses: actions/upload-artifact@v4
  with:
    name: ollama-image
    path: ollama-models.tar.gz
    retention-days: 1

# In publish:
- uses: actions/download-artifact@v4
  with:
    name: ollama-image
- name: Load and retag image
  run: |
    docker load < ollama-models.tar.gz
    docker tag ollama-models:ci ghcr.io/${{ env.OWNER }}/dotfiles/ollama-models:latest
    docker push ghcr.io/${{ env.OWNER }}/dotfiles/ollama-models:latest
```
Note: At ~27GB compressed this may exceed artifact storage limits. An alternative is to use a registry as the intermediary (push to GHCR as `:ci-sha`, validate, then retag to `:latest`).

---

## Info

### IN-01: Dockerfile model size comment is inconsistent with workflow comment

**File:** `Dockerfile.ollama:4` vs `.github/workflows/build-ollama.yml:151`
**Issue:** The Dockerfile header says `gemma4:e4b (~9.6GB)` but the workflow "Note GHCR multi-layer push" step says `gemma4:e4b (~9.6GB)` — these match. However, `gemma4:26b` is listed as `~18GB` in the Dockerfile but `~18GB` in the workflow. These are consistent now but the Dockerfile line 7 says `~17GB minimum disk` while line 37 says `~18GB` for the model itself. Minor inconsistency worth aligning.

**Fix:** Standardize: the GHCR layer limits comment (line 17-21) says `~17GB` total minimum disk but the individual model comment (line 37) says `~18GB`. Update line 17-21 to reference actual model sizes (~18GB + ~9.6GB = ~27.6GB minimum).

---

### IN-02: `kill $_pid && wait` pattern may leave orphaned server on pull failure

**File:** `Dockerfile.ollama:55,74`
**Issue:** Both model-pull RUN layers use `kill $_pid && wait $_pid 2>/dev/null || true`. If `ollama pull` fails (network error, disk full), the script will exit non-zero before reaching `kill $_pid`, leaving the background server process running. Docker build will cancel the layer, but in local builds this can leave stale processes. The `|| true` on `wait` is correct, but the `kill` should be in a cleanup trap.

**Fix:** Add a trap at the start of the RUN layer:
```dockerfile
RUN OLLAMA_HOST=127.0.0.1:11235 ollama serve & \
    _pid=$! && \
    trap "kill $_pid 2>/dev/null; wait $_pid 2>/dev/null; exit 1" ERR INT TERM && \
    ...
    kill $_pid && wait $_pid 2>/dev/null || true
```

---

### IN-03: Lint job installs ShellCheck but checks nothing

**File:** `.github/workflows/build-ollama.yml:41-46`
**Issue:** The `lint` job installs ShellCheck and then prints a message saying there are no shell scripts to check. This wastes ~10-15 seconds per run and creates a misleading job name in the CI summary. It also means `build-and-test` always waits on a no-op job.

**Fix:** Either remove the lint job entirely for this phase and remove `needs: lint` from `build-and-test`, or make the lint job conditional:
```yaml
lint:
  name: Lint (ShellCheck)
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Run ShellCheck on any .sh files
      run: |
        mapfile -t scripts < <(find . -name '*.sh' -not -path './.git/*')
        if [ ${#scripts[@]} -eq 0 ]; then
          echo "No shell scripts found — skipping"
        else
          shellcheck "${scripts[@]}"
        fi
```

---

_Reviewed: 2026-04-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
