---
name: writing-plans
description: Convert an approved spec into a tactical implementation plan with bite-sized tasks. Save to docs/superpowers/plans/YYYY-MM-DD-<topic>.md.
---

## Purpose

Take an approved spec and produce a tactical plan: file structure, decomposed tasks, each step shown with exact content. The plan is what an executor — human or agent — can run task-by-task without re-deriving context.

## Behavior

1. Read the spec at the path provided (typically from a `brainstorming` hand-off).
2. Map out the file structure first. Which files will be created or modified, and what is each responsible for. Lock decomposition in before defining tasks.
3. Define tasks. Each task is a logical unit (typically 15–30 minutes) broken into 2–5 minute steps.
4. Each step shows EXACT content: file paths, full code blocks, exact commands, expected output. No "TBD", no "implement later", no "add appropriate error handling", no "similar to Task N". Those are plan failures — they push synthesis onto the executor.
5. Tasks for new behavior follow TDD: write a failing test → run to confirm fail → minimal implementation → run to confirm pass → commit.
6. Tasks for deletions follow regression-test-first: write tests against current behavior → confirm pass → delete → confirm tests still pass → commit.
7. Save the plan to `docs/superpowers/plans/YYYY-MM-DD-<topic>.md` (today's date).
8. Self-review: does every spec section have a task? Any placeholders? Type and signature consistency across tasks?

### Next step (required)

After saving the plan, hand off to either:

- `executing-plans` — for sequential inline execution by the current controller.
- `subagent-driven-development` — when the plan has parallel-safe tasks or scope justifies dispatch overhead.

The plan document MUST end with an explicit hand-off line stating which downstream skill the executor should invoke. State it; don't imply it.

### See also

- `brainstorming` — the upstream feeder; produces the spec this skill consumes.
- `executing-plans` and `subagent-driven-development` — the two downstream options.
