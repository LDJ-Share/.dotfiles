---
name: tiered-subagent-dispatch
description: Match subagent model tier to task complexity — inline for trivial, haiku for mechanical batches, sonnet+opus-review for algorithmic work. Use when dispatching multi-task plans.
---

## Purpose

Uniform subagent dispatch wastes tokens. Match the model tier to the task: a haiku batch can do an hour of plan-literal edits in one shot, while algorithmic work warrants a sonnet implementer with a single opus review. Picking the right tier per task is the single biggest lever on cost and throughput.

## Behavior

1. Inspect the task before choosing a tier. The dispatcher reads the task; the subagent does not pick its own model.
2. **Plain type records** — single-file additions with no logic. Implement inline with `Edit`/`Write`. No subagent.
3. **Mechanical work** — deletes, DI wiring, csproj edits, plan-literal file edits, search-replace refactors. Dispatch ONE haiku subagent per batch (multiple sequential tasks per dispatch). Skip review loops.
4. **Algorithmic work** — matchers, scorers, workflows, retry logic, multi-file integrations. Dispatch a sonnet implementer plus ONE combined opus spec+quality review (not two separate reviewers).
5. Point subagents at the plan section by file path + task number. Don't inline full code blocks — saves 2–3k tokens per dispatch.
6. Cap reviewer output at ~150 words. Critical and Important findings only; skip Minor and Nit.
7. Run the project's build + test suite after every implementer dispatch, regardless of tier.
8. Drop per-task commentary. Batch status updates to every 3–5 tasks or at phase boundaries.
9. Target ~10k tokens per task across implementer + reviewer combined. If a single task is consuming far more, the task is too large — split it.

### See also

- `subagent-driven-development` — the dispatcher itself; this skill defines its model-selection policy.
- `verifying-subagent-output` — post-dispatch verification, especially for haiku tier.
