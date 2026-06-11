---
description: Autonomously triage a failing/buggy integration suite — parallel investigation, then drain fixes — until the queue is empty or a stop-condition trips.
argument-hint: [test filter or path, optional]
---
Run the integration-test triage workflow. First invoke the `orchestration-protocol`
skill — it defines the orchestrator contract (high-altitude loop, centralized beads
writes, watchdog, interjection steering, beads safety, Seance log). Stay high-altitude:
never read files or logs yourself — delegate. For .NET-specific subtasks (build
errors, test run/filter, perf), lean on the installed dotnet skills per
`orchestration-protocol` ("Lean on the dotnet skills for .NET specifics").

Scope: $ARGUMENTS  (if empty, the whole suite)

## Decision charter (autonomous authority)
SPINE: a test that goes red -> green must still assert the same thing or MORE,
never less. Making a test pass by weakening it is the failure mode this charter
exists to prevent. (Tune the three numbers below to taste; start conservative.)

You MAY, without asking:
- Run the suite, file/close beads, dispatch investigators/implementers/verifiers.
- Fix product bugs by editing `src/**` `.cs` files.
- Fix genuine test bugs (wrong expected value, bad setup, incorrect mock) in test
  `.cs` files — only if the assertion still proves the original intent.
- Re-run a suspected-flaky test up to 2x to confirm; if confirmed, quarantine it
  with `[Trait("Category","Flaky")]` and file a bead — do NOT silently "fix" it.

You MUST STOP and report (do not proceed) if a fix would:
- Skip, ignore, delete, or comment out a test or assertion
  (`[Fact(Skip=...)]`, `[Ignore]`, removing `[Theory]`/`[InlineData]` cases,
  commenting out an `Assert`).
- Weaken an assertion (loosen tolerance, swap for a weaker check, swallow an
  exception, add a try/catch that hides failure).
- Add retry / Polly / Thread.Sleep to PRODUCT code to mask timing or flakiness.
- Change a public API, contract, or DTO shape.
- Touch build/infra/config: `*.csproj`, `Directory.Build.*`,
  `Directory.Packages.props`, EF migrations, `appsettings*.json`,
  `docker-compose*`, `.github/**`, CI YAML.
- Be classified `environment` (missing DB/container/secret) — escalate; do NOT
  reconfigure the environment.

Hard halts (stop the whole run, report):
- The passing-test count drops below the starting baseline (a fix broke others).
- 3 consecutive verifier FAILs on the same bead.
- Watchdog: K=3 consecutive no-progress passes, or MAX_PASSES=50 total (orchestration-protocol skill).
- 10 beads closed this run — pause for a human checkpoint.
- Any git operation beyond local commits (no push, no force, no history edits).

## Loop
1. `bd prime`. Establish a baseline: dispatch `verifier` once to run the suite
   (scoped by $ARGUMENTS). File one bead per failing test.
2. INVESTIGATE IN PARALLEL: dispatch a batch of `investigator` agents — one per
   failing-test bead — in a SINGLE message (read-only, so no write races).
3. For each returned diagnosis: file a fix bead and `bd dep add <fix> <test>`
   (discovered-from). `bd remember` any cross-cutting cause.
4. DRAIN FIXES: while `bd ready --exclude-label interjection` has fix beads and no stop-condition tripped —
   claim one, dispatch `implementer`, then `verifier`. On a green verifier,
   dispatch `reviewer` on the diff BEFORE closing — its job here is to confirm
   no assertion was weakened, skipped, or swallowed (the charter's spine). On a
   `ship` verdict, `bd close`. A `fix-first` verdict that flags a weakened/
   skipped assertion is a HARD HALT (charter); any other `fix-first` loops the
   bead back to `implementer`. On a red verifier, re-investigate or escalate.
5. Re-run the baseline. Repeat from step 2 for any still-failing tests until the
   suite is green or a stop-condition trips. At the TOP of each pass, fold in
   any open interjection beads (`bd list --label interjection`, close each) per orchestration-protocol. Run
   the watchdog: a pass with zero beads closed AND zero new beads filed counts as
   no-progress — halt at K=3 consecutive, or at MAX_PASSES=50.
6. Report: beads closed, beads still open, what (if anything) you stopped on.

For runs longer than one session, re-enter this loop with `/loop` or the
ralph-loop plugin — state survives in beads + git, so re-entry loses nothing.
