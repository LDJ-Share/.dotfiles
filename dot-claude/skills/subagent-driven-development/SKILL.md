---
name: subagent-driven-development
description: Execute a written plan by dispatching fresh subagents per task (or per batch, per the tiered-subagent-dispatch policy). Coordinate state in the controller; preserve subagent context isolation.
---

## Purpose

A controller dispatches fresh subagents per task instead of executing inline. The controller carries plan state and review history; each subagent gets a clean context window for its specific task. Costs more tokens than inline execution but scales further on long plans.

## Behavior

1. Read the plan once. Extract every task's full text and supporting context up front. Subagents shouldn't re-read the plan file — wastes tokens.
2. Create a TodoWrite list mirroring the plan's tasks. Update statuses as work progresses.
3. For each task (or batch, per `tiered-subagent-dispatch`):
   - Dispatch the implementer subagent with full task text inline.
   - If the subagent reports NEEDS_CONTEXT, answer questions and re-dispatch.
   - If it reports BLOCKED, assess: more context, a more capable model, a smaller task, or escalate to the user.
   - If it reports DONE_WITH_CONCERNS, read the concerns; address correctness or scope concerns before any review step.
   - If it reports DONE, run verification per `verifying-subagent-output`.
4. Per tier: mechanical work batches under one haiku dispatch with NO review loop. Algorithmic work uses a sonnet implementer plus ONE combined opus spec+quality review.
5. Never dispatch multiple implementer subagents in parallel on overlapping files — race conditions on the working tree are silent and ugly to debug.
6. After all tasks complete, dispatch `final-branch-review` before declaring the branch done.

### See also

- `tiered-subagent-dispatch` — defines model selection per task.
- `verifying-subagent-output` — post-dispatch verification, especially for haiku tier.
- `final-branch-review` — branch-end gate.
- `requesting-code-review` — per-change review pattern available mid-execution.
