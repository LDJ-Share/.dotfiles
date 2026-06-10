---
name: final-branch-review
description: Before declaring a branch done or merging, dispatch an opus reviewer across master..HEAD. Catches cross-task interactions per-task reviews miss.
---

## Purpose

Per-task reviews structurally miss interactions: dead code from incremental deletes, doc drift, type inconsistencies between tasks, orphaned helpers, stale comments. A full-branch review at the end catches what the slice-by-slice view never sees.

## Behavior

1. Before claiming a feature branch ready to merge, dispatch a single opus subagent for full-branch review.
2. Scope: `master..HEAD` (substitute `main` or whatever the actual base branch is).
3. The reviewer reads the spec, the plan, and the diff. It verifies the spec was honored, then looks for cross-task issues per-task reviews would miss.
4. Cap reviewer output at ~250 words. Sections: Completion / CRITICAL / IMPORTANT / OBSERVATIONS. Skip Minor and Nit.
5. If CRITICAL items appear, fix them before merging — either inline or via a follow-up implementer dispatch.
6. If only OBSERVATIONS or IMPORTANT items appear, evaluate scope: fix in-branch when cheap; defer when fixing would expand scope past the original goal.

### When NOT to use

Trivial fixes — single-commit doc edits, single-file bug fixes — where `master..HEAD` reduces to one diff already covered by per-task review. The full-branch review is overhead-justified for multi-task feature work, not single-commit changes.

### See also

- `requesting-code-review` — per-change variant that fires earlier in the lifecycle.
- `finishing-a-development-branch` — the natural caller; runs this review before presenting merge/PR options.
