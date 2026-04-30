---
name: requesting-code-review
description: Dispatch a reviewer subagent for a specific change. Use after implementing a non-trivial commit or before merging when the change warrants targeted review.
---

## Purpose

Per-change review at task or commit boundaries. A focused second opinion on a specific diff, not the whole codebase. Distinct from `final-branch-review`, which scans the whole `master..HEAD`.

## Behavior

1. Use the Agent tool with model selection appropriate to the change: sonnet for routine review, opus for high-blast-radius work (security, infrastructure, broad refactors).
2. Scope the review to the specific change under consideration — a single commit, a single file, a feature increment. Not the whole codebase.
3. Provide the reviewer with: the spec or task description, the relevant commit SHAs, and the file paths under review. Don't make the reviewer re-derive context.
4. Cap reviewer output at ~150 words. Critical and Important findings only; skip Minor and Nit.
5. Fix Critical and Important findings before moving on. Defer or document Minor findings.
6. Don't dispatch reviewers in parallel on overlapping files — they can produce contradictory advice and you'll waste time reconciling.

### When NOT to use

Trivial commits — typo fixes, single-line tweaks — where review overhead exceeds the change.

### See also

- `final-branch-review` — whole-branch variant; usually fires later in the lifecycle.
