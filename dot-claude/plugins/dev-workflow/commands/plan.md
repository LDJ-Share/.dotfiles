---
description: Convert an approved spec into a tactical, task-by-task implementation plan.
argument-hint: [spec path, optional]
---
Invoke the `writing-plans` skill for the spec at: $ARGUMENTS
(If no path is given, use the most recent spec under `docs/superpowers/specs/`.)

Lock the file structure first, then decompose into bite-sized tasks with EXACT
content (no "TBD"/"implement later"). New behavior follows TDD; deletions follow
regression-test-first. Save to `docs/superpowers/plans/YYYY-MM-DD-<topic>.md` and
end the plan with an explicit hand-off line (`/execute` for inline, or the
`subagent-driven-development` skill for dispatch).

For **autonomous, model-approved** planning inside an orchestration loop (no human
approval pause — the orchestrator approves the plan itself, bounded by its charter),
use `plan-first-dispatch` from the orchestrator plugin instead of this command.
