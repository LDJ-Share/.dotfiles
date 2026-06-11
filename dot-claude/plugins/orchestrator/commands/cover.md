---
description: Parallelize unit-test coverage across a low-coverage codebase — decompose into per-unit beads, fan out test-writers on disjoint files, verify, drain.
argument-hint: [target path and/or coverage threshold, optional]
---
Run the coverage workflow. First invoke the `orchestration-protocol` skill — it
defines the orchestrator contract (high-altitude loop, centralized beads writes,
watchdog, interjection steering, beads safety, Seance log). Stay high-altitude: never read
source yourself — delegate.

Scope/target: $ARGUMENTS

## Language routing (.NET)
This is a .NET repo. Prefer the `dotnet-test` skills where available — they
handle framework detection, coverage, and CRAP scoring. Use `test-writer` agents
for the actual per-unit writing.

## Loop
1. `bd prime`. Dispatch a `scout`/coverage pass to produce the gap list:
   `dotnet test --collect:"XPlat Code Coverage"` (Cobertura via coverlet), then
   summarize per-class line/branch coverage with `reportgenerator` or the
   `dotnet-test coverage-analysis` skill. Prioritize by lowest coverage + highest
   churn (CRAP score if available).
2. File one bead per unit to cover. Prioritize untested + high-churn first.
3. PARTITION FOR PARALLEL WRITES: group beads so no two in a batch touch the same
   file. New test files are naturally disjoint; YOU own edits to shared files
   (test project file, fixtures, config).
4. FAN OUT: dispatch a batch of `test-writer` agents (one per disjoint bead) in a
   SINGLE message. Apply any reported "shared-file changes" yourself, serially.
5. VERIFY: dispatch `verifier` on the new tests. On green, `bd close`.
6. Repeat from step 3 until `bd ready --exclude-label interjection` is empty or the coverage threshold is met.
   At the TOP of each pass, fold in any open interjection beads
   (`bd list --label interjection`, then close each) per orchestration-protocol. Run the watchdog: a pass with zero beads closed
   AND zero new beads filed is no-progress — halt at K=3 consecutive, or at
   MAX_PASSES=50, emitting a Seance escalation with passes run + beads closed.
7. Report: coverage before/after, beads closed, anything blocked.

Write-isolation note: if units can't be cleanly partitioned by file, run
test-writers in separate git worktrees and merge after (see the orchestration-protocol skill's patterns reference).
