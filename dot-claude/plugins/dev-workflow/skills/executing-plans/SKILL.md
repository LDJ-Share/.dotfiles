---
name: executing-plans
description: Follow a written implementation plan task-by-task with checkpoints. Run tests at each gate; commit per task; pause for review at natural breakpoints.
---

## Purpose

Inline task-by-task execution of a written plan. Alternative to `subagent-driven-development`, which dispatches subagents. Use when the controller (you) has full plan context already and inline execution is cheaper than dispatch overhead.

## Behavior

1. Receive a plan path — either as a skill argument or via a `writing-plans` hand-off.
2. Read the plan once. Identify the task list and any phase boundaries.
3. Execute tasks sequentially. For each task:
   - Read the steps and expected outputs.
   - Implement.
   - Run any verification commands the task specifies.
   - Commit using the task's prescribed commit message.
   - Update the task tracker (TodoWrite or equivalent).
4. At natural checkpoints — end of phase, after a gnarly multi-file task, before any destructive operation — pause and surface progress to the user.
5. If you discover the plan is wrong (a task's instructions don't fit reality), stop and surface. Don't improvise around the plan silently.
6. At the end of the plan, hand off to `finishing-a-development-branch` for the merge/PR/keep/discard decision. Don't merge unilaterally.
7. If work is incomplete at session end, write a handoff doc at `docs/superpowers/handoff/YYYY-MM-DD-<topic>-next-session.md` summarizing state.

### See also

- `subagent-driven-development` — alternative for plans where dispatch overhead is justified.
- `verification-before-completion` — per-task verification.
- `iterative-review-before-commit` — for sensitive commits encountered during execution.
- `requesting-code-review` — mid-execution review at non-trivial task completion.
- `finishing-a-development-branch` — handles end-of-plan.
