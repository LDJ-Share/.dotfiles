---
name: iterative-review-before-commit
description: For security-sensitive, infrastructure-touching, or broad-impact changes, present diffs for user review BEFORE running git commit. Never auto-commit those.
---

## Purpose

Past auto-commits on security and infrastructure scripts have produced regressions caught only after the fact. The fix is a discipline, not a tool: stage, present the diff, wait for explicit approval, then commit.

## Behavior

1. Detect sensitive scope before any commit. Sensitive scope means changes that touch:
   - Security boundaries: auth, secrets, firewall scripts, sudoers, capability drops.
   - Infrastructure: Dockerfiles, CI workflows, git hooks, `settings.json`.
   - Broad impact: renames affecting more than 5 files, deletes of top-level directories.
2. When sensitive scope is detected, STAGE the changes but do NOT run `git commit`.
3. Present a unified diff to the user via `git diff --staged`.
4. Wait for explicit approval — "approve", "commit", "looks good". Silence is not approval.
5. For non-sensitive changes (docs, internal refactors, single-file bug fixes), commit normally without the gate.
6. If the user requests a tweak: stash or unstage the change, apply the tweak, re-stage, and re-present.

### When NOT to use

Routine docs, internal-only refactors, formatting-only commits. Gating those generates alert fatigue and slows the user down for no benefit.

### See also

- `verification-before-completion` — sibling discipline for "done" claims; this skill is its commit-time analogue.
