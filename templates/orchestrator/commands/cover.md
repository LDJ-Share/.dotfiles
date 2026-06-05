---
description: Parallelize unit-test coverage across a low-coverage codebase — decompose into per-unit beads, fan out test-writers on disjoint files, verify, drain.
argument-hint: [target path and/or coverage threshold, optional]
---
Run the coverage workflow as the ORCHESTRATOR defined in CLAUDE.md.
Stay high-altitude: never read source yourself — delegate.

Scope/target: $ARGUMENTS

## Language routing
If this is a .NET repo and the `dotnet-test` skills are available, use them for
coverage analysis and test generation (they handle framework detection, coverage,
and CRAP scoring) instead of a generic writer. Otherwise use `test-writer`.

## Loop
1. `bd prime`. Dispatch a `scout`/coverage pass to produce the gap list. Run the
   coverage command — fill in for this repo, e.g.
   `dotnet test --collect:"XPlat Code Coverage"` / `pytest --cov` / `jest --coverage`.
2. File one bead per unit to cover. Prioritize untested + high-churn first.
3. PARTITION FOR PARALLEL WRITES: group beads so no two in a batch touch the same
   file. New test files are naturally disjoint; YOU own edits to shared files
   (test project file, fixtures, config).
4. FAN OUT: dispatch a batch of `test-writer` agents (one per disjoint bead) in a
   SINGLE message. Apply any reported "shared-file changes" yourself, serially.
5. VERIFY: dispatch `verifier` on the new tests. On green, `bd close`.
6. Repeat from step 3 until `bd ready` is empty or the coverage threshold is met.
7. Report: coverage before/after, beads closed, anything blocked.

Write-isolation note: if units can't be cleanly partitioned by file, run
test-writers in separate git worktrees and merge after (see PATTERNS.md).
