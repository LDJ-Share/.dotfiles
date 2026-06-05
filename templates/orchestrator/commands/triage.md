---
description: Autonomously triage a failing/buggy integration suite — parallel investigation, then drain fixes — until the queue is empty or a stop-condition trips.
argument-hint: [test filter or path, optional]
---
Run the integration-test triage workflow as the ORCHESTRATOR defined in CLAUDE.md.
Stay high-altitude: never read files or logs yourself — delegate.

Scope: $ARGUMENTS  (if empty, the whole suite)

## Decision charter (autonomous authority — CUSTOMIZE BEFORE FIRST RUN)
You MAY, without asking:
- File beads, run the suite, dispatch investigators/implementers/verifiers.
- Fix clearly-diagnosed product bugs and test bugs; refactor a test for clarity.
- Mark flaky tests and file a bead to stabilize them.

You MUST STOP and report (do not proceed) if:
- A fix requires a public API / schema / contract change.
- A fix means deleting or skipping a test, or touching files outside <ALLOWLIST>.
- 3 consecutive verifier FAILs on the same bead, or the suite gets worse than baseline.
- You would close more than <N> beads in one run without a checkpoint.

## Loop
1. `bd prime`. Establish a baseline: dispatch `verifier` once to run the suite
   (scoped by $ARGUMENTS). File one bead per failing test.
2. INVESTIGATE IN PARALLEL: dispatch a batch of `investigator` agents — one per
   failing-test bead — in a SINGLE message (read-only, so no write races).
3. For each returned diagnosis: file a fix bead and `bd dep add <fix> <test>`
   (discovered-from). `bd remember` any cross-cutting cause.
4. DRAIN FIXES: while `bd ready` has fix beads and no stop-condition tripped —
   claim one, dispatch `implementer`, then `verifier`. On green, `bd close`.
   On red, re-investigate or escalate per the charter.
5. Re-run the baseline. Repeat from step 2 for any still-failing tests until the
   suite is green or a stop-condition trips.
6. Report: beads closed, beads still open, what (if anything) you stopped on.

For runs longer than one session, re-enter this loop with `/loop` or the
ralph-loop plugin — state survives in beads + git, so re-entry loses nothing.
