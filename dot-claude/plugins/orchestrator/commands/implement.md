---
description: Autonomously implement a task/feature — decompose in parallel, then drain the implementation through implementer + verifier + reviewer-gate — until the work is done or a stop-condition trips.
argument-hint: [task description, or a bead id / area path]
---
Run the implementation workflow — the general-purpose sibling of `/triage`
(specialized to a failing suite) and `/cover` (specialized to coverage). First
invoke the `orchestration-protocol` skill — it defines the orchestrator contract
(high-altitude loop, centralized beads writes, watchdog, interjection steering, beads
safety, Seance log). Stay high-altitude: never read source or run builds yourself —
delegate; only bead IDs, one-paragraph summaries, and pass/fail land in your window.
For .NET-specific subtasks (build errors, test run/filter, coverage, migrations),
lean on the installed dotnet skills per `orchestration-protocol` ("Lean on the
dotnet skills for .NET specifics").

Scope: $ARGUMENTS  (a task in words, or a bead id, or an area path)

## Decision charter (autonomous authority)
SPINE: the change must satisfy the acceptance criteria **and keep every existing
test as strong or stronger**. Making the build/tests pass by weakening, skipping,
or deleting an assertion is the failure mode this charter prevents — never expand
scope to "improve" unrelated code.

You MAY, without asking:
- Decompose the task into beads; file/close beads; dispatch
  scouts/implementers/verifiers/reviewers.
- Implement the change by editing `src/**` and adding/extending tests for the new
  behavior.
- Fix a genuine test bug you introduced (wrong expected value, bad setup) — only
  if the assertion still proves the original intent.

You MUST STOP and report (do not proceed) if proceeding would:
- Weaken/skip/delete/swallow an existing test or assertion.
- Change a public API, contract, DTO shape, or on-disk/wire format — unless the
  task explicitly asks for it (then still flag the blast radius).
- Touch build/infra/config (`*.csproj`, `Directory.Build.*`,
  `Directory.Packages.props`, EF migrations, `appsettings*.json`,
  `docker-compose*`, `.github/**`, CI YAML) beyond what the task plainly requires.
- Exceed the stated scope (a refactor you "noticed", a dependency bump) — file it
  as a discovered bead instead.
- Be ambiguous about intent or acceptance — pause for human steering (via `/notify`), don't guess.

Hard halts (stop the whole run, report):
- The pre-existing passing-test count drops below the starting baseline.
- 3 consecutive verifier FAILs on the same bead.
- Watchdog: K=3 consecutive no-progress passes, or MAX_PASSES=50 (orchestration-protocol skill).
- 10 beads closed this run — pause for a human checkpoint.
- Any git operation beyond local commits (no push, no force, no history edits).

## Loop
1. `bd prime`. **Establish scope & baseline.** If $ARGUMENTS is a description,
   dispatch `scout`(s) in parallel to map the area and turn the task into a
   concrete set of beads (acceptance criteria each); `bd dep add <subtask> <parent>`
   (discovered-from). If it's an existing bead, decompose it. Dispatch `verifier`
   once to record the green baseline (the test count a fix must never drop below).
2. **PARTITION FOR PARALLEL WRITES.** Order beads by dependency; group so no two in
   a batch touch the same file. Independent beads may run concurrently; YOU own
   edits to shared files. Two implementers on one file = lost writes — partition by
   file, or give each its own git worktree and merge after.
3. **DRAIN.** While `bd ready --exclude-label interjection` has actionable beads and no stop-condition tripped:
   claim one (`bd update <id> --claim`); if the area is unfamiliar dispatch `scout`
   first; **plan first** (`plan-first-dispatch`) for non-trivial beads — dispatch
   `planner`, persist its plan, and auto-approve it *bounded by this charter* (a plan
   that would trip any "MUST STOP" / hard-halt above → STOP and report, not approved);
   dispatch `implementer` (bead id + acceptance criteria + scout map + approved plan);
   then `verifier`. On a red verifier, re-scope or escalate.
4. **GATE & CLOSE.** On green, dispatch `reviewer` on the diff BEFORE closing —
   confirm the change meets the criteria, stays in scope, and weakened no
   assertion. On a `ship` verdict, `bd close <id> "<one-line outcome>"`. A
   `fix-first` flagging a weakened/skipped/out-of-scope change is a HARD HALT; any
   other `fix-first` loops the bead back to `implementer`.
5. At the TOP of each pass (before selecting work in step 3), fold in any open
   interjection beads (`bd list --label interjection`, close each). Run
   the watchdog: a pass with zero beads closed AND zero new beads filed
   is no-progress — halt at K=3 consecutive, or MAX_PASSES=50. File discovered work
   as new beads rather than absorbing it. Emit a Seance event per lifecycle step.
6. Report: beads closed (what shipped), still open, what (if anything) you stopped
   on, and discovered follow-ups.

For runs longer than one session, re-enter this loop with `/loop` or the ralph-loop
plugin — state survives in beads + git, so re-entry loses nothing.
