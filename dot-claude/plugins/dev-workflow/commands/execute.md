---
description: Execute a written implementation plan task-by-task with verification gates and checkpoints.
argument-hint: [plan path, optional]
---
Invoke the `executing-plans` skill for the plan at: $ARGUMENTS
(If no path is given, use the most recent plan under `docs/superpowers/plans/`.)

Execute tasks sequentially: implement → run the task's verification → commit with
the prescribed message → update the tracker. Pause at phase boundaries and before
destructive steps. If the plan has parallel-safe tasks or scope justifies dispatch
overhead, switch to the `subagent-driven-development` skill instead (per
`tiered-subagent-dispatch`). At the end, hand off to `/finish`.
