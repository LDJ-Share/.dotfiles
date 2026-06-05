# Reusable patterns

Two execution patterns layer on top of the orchestrator backbone. Both keep the
orchestrator high-altitude; only the topology changes.

## 1. Parallel fan-out

Dispatch many subagents at once instead of looping one at a time. In vanilla
Claude Code (no Workflow tool), the orchestrator does this by issuing MULTIPLE
Agent/Task tool calls in a SINGLE message — they run concurrently. Collect all
the structured returns, then act on them.

Write-safety decides how far you can fan out:
- **Read-only agents (scout, investigator, verifier)** — fan out freely. Nothing
  is written, so there are no collisions.
- **File-writing agents (implementer, test-writer)** — only safe in parallel if
  each touches a DISJOINT set of files. Either partition the work by file (the
  orchestrator owns shared files), or give each agent its own **git worktree**
  and merge after. Two agents editing the same file in parallel = lost writes.

If a `dispatching-parallel-agents` skill is available, use it — it encodes the
batching and result-collection discipline.

## 2. Autonomous drain

"Keep going" = loop until `bd ready` is empty or a stop-condition trips, without
checking in each step. Three ingredients:
- **The loop** — claim ready bead → dispatch → verify → close/escalate → repeat.
  Because the orchestrator window stays tiny, one session runs many iterations.
- **A decision charter** — written, explicit: what the run may decide alone vs.
  what forces a STOP-and-report. No charter = runaway. (See `commands/triage.md`.)
- **An audit trail** — beads history (`bd show`) + `bd remember` capture what the
  run did and learned, so you can review after the fact.

For runs longer than one session, re-enter the loop with `/loop` or the
ralph-loop plugin. State lives in beads + git, so re-entry loses nothing.

## When you have the Workflow tool

The Workflow tool replaces the manual versions of both patterns with
deterministic scripting (it requires explicit opt-in). The agent roster and the
beads contract DO NOT change — only where the control flow lives:

- **Fan-out** → `parallel(thunks)` (barrier; collect all) or `pipeline(items, ...)`
  (no barrier; each item flows through stages independently). File-writing agents
  take `isolation: 'worktree'` per agent to remove write races automatically.
- **Autonomous drain** → a `while` loop in the script (loop-until-dry: keep
  fanning out until K rounds find nothing new), bounded by `budget.remaining()`
  instead of a hand-tuned bead cap.
- **Verify-as-you-go** → the canonical `pipeline(beads, fix, verify)` so each fix
  is verified the moment it lands, instead of a separate drain phase.

Migration: lift the loop bodies out of `commands/triage.md` and `commands/cover.md`
into a Workflow script; keep `bd` calls for state and the same agents as the
script's `agent()` targets.
