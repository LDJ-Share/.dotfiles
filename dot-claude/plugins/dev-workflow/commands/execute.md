---
description: Execute a written implementation plan task-by-task with verification gates and checkpoints.
argument-hint: [plan path, optional]
---
Invoke the `executing-plans` skill for the plan at: $ARGUMENTS
(If no path is given, use the most recent plan under `docs/superpowers/plans/`.)

**Always have a plan.** If there's no plan for this work yet, don't dive straight
in — produce one first. Inside an orchestration loop (orchestrator plugin installed),
use `plan-first-dispatch`: dispatch the `planner` agent, auto-approve its plan
*bounded by the charter* (a plan that would weaken tests, change a public contract,
touch build-infra, or exceed scope is surfaced, not auto-approved), then implement it.
Solo, just write the plan with `/plan` first. Skip planning only for a trivial,
single-file, obviously-correct change.

On a **.NET** repo, lean on the installed **dotnet-agent-skills** for build/test
specifics rather than reasoning from memory: build failures → `dotnet-msbuild`, test
run/filter/coverage → `dotnet-test`, core C# mechanics → `dotnet`. See the README's
"Recommended additional skills". If not installed, proceed normally.

Execute tasks sequentially: implement → run the task's verification → commit with
the prescribed message → update the tracker. Pause at phase boundaries and before
destructive steps. If the plan has parallel-safe tasks or scope justifies dispatch
overhead, switch to the `subagent-driven-development` skill instead (per
`tiered-subagent-dispatch`). At the end, hand off to `/finish`.
