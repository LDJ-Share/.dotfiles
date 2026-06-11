---
description: Autonomously build Appium component (UI-smoke) tests — parallel authoring, serialized live execution through ONE runner, optional reviewer-gate — until the target set is covered or a stop-condition trips.
argument-hint: [app/area to cover, optional]
---
Run the component-test build workflow as a context-frugal ORCHESTRATOR (beads + git
hold state; you stay near-empty on a Sonnet-4.5 / 200k window). This plugin ships
everything it needs — the charter, loop, and single-executor invariant are inline
below, and all four worker agents (`scout`, `component-test-builder`,
`appium-interactive-runner`, `reviewer`) belong to this plugin; there is no external
dependency. (If the `orchestrator` plugin is installed, its `orchestration-protocol`
skill covers beads safety + the Seance decision-log format in more depth.) Stay
high-altitude: never read source, run builds, or drive the app yourself — every
substantive action happens inside a disposable subagent; only bead IDs,
one-paragraph summaries, and pass/fail land in your window. When a
`component-test-builder`'s `dotnet build` fails for a .NET reason (not a
test-authoring bug) or you need a precise `dotnet test` filter, dispatch the
matching dotnet skill/agent (`dotnet-msbuild:msbuild`, `dotnet-test:filter-syntax`)
from the installed **dotnet-agent-skills** rather than reasoning from memory — see
the README's "Recommended additional skills". If not installed, proceed normally.

Scope: $ARGUMENTS  (if empty, the app's main user-facing surface)

## The invariant that shapes everything (interactive tests)
Component tests are **interactive**: each one launches the app and drives a single
desktop / UIA session. Execution cannot be parallelized.

- **Exactly ONE `appium-interactive-runner` in flight at any time.** It is the
  *only* agent allowed to start Appium, launch the app, or run the `UiSmoke`
  category. Never dispatch two runners at once; never fan a runner out in a
  parallel batch. **Never** use a generic `verifier` on `UiSmoke` tests — that
  would collide with the runner; the runner IS the verifier here.
- **Authoring CAN be parallel.** `component-test-builder`s only write code and
  `dotnet build` — fan them out, one per bead, as long as their test files are
  disjoint (they are, by bead). YOU own edits to shared files (test `.csproj`,
  base fixture). For non-disjoint writes, give each builder its own git worktree.
- Read-only `scout`/`reviewer` (this plugin's own) fan out freely.

## Decision charter (autonomous authority)
SPINE: a component test must assert **real, observable** app behavior. A test that
launches the app and asserts nothing meaningful (or only `PageSource.Contains`, or
a tautology) is hollow — that is the failure mode this charter prevents.

You MAY, without asking:
- File/close beads; dispatch builders (parallel) and the single runner (serial).
- Add tests and the `AutomationId`s they require to app XAML (via the builder).
- Re-run a suspected-flaky fixture up to 2x via the runner; if confirmed flaky,
  file a bead — never paper over it with a sleep/retry.

You MUST STOP and report (do not proceed) if building a test would:
- Assert nothing real / weaken or delete an existing assertion to make it pass.
- Add `Thread.Sleep`/retry/Polly to PRODUCT code to mask UI timing.
- Change a public API, contract, or DTO shape.
- Touch build/infra/config (`*.csproj` beyond adding the test, `Directory.*`,
  `appsettings*`, CI YAML) beyond the test project's own first-time setup.

Hard halts (stop the run, report):
- The fast unit gate goes red (a test change broke the build for everyone).
- 3 consecutive runner FAILs on the same bead.
- Watchdog: K=3 consecutive no-progress passes, or MAX_PASSES=50.
- 10 beads closed this run — human checkpoint.
- Any git operation beyond local commits.

## Loop
1. `bd prime`. **Decompose:** dispatch `scout`(s) in parallel to map the target
   surface — which views/flows lack a component test, what `AutomationId`s already
   exist, the fixture/category conventions. File one bead per component-test
   target, kept **atomic** — one bead = one test = one verifiable outcome; split a
   target that needs several distinct flows/assertions into separate beads.
   Prioritize untested user-facing flows. `bd dep add` discovered subtasks, and
   file discovered app-bugs / follow-ups as their own beads rather than folding
   them in.
2. **AUTHOR IN PARALLEL.** Dispatch a batch of `component-test-builder`s — one per
   bead, disjoint files — in a SINGLE message. Each writes its fixture, adds the
   AutomationIds it needs, compiles, and returns a **run-request**. Apply any
   reported shared-file changes yourself, serially.
3. **EXECUTE SERIALLY (the bottleneck).** For each authored bead, **one at a
   time**, dispatch the single `appium-interactive-runner` with the builder's
   run-request. It runs the test live and, on FAIL/HANG/FLAKY, interactively debugs
   and returns a prescribed locator/data fix.
   - Runner PASS → go to the gate.
   - Runner FAIL with a prescribed fix → loop the bead back to its
     `component-test-builder` (apply the fix), then re-run. Count consecutive FAILs
     per bead (hard-halt at 3).
   - Runner classifies `app-bug` → file a bug bead (don't weaken the test to pass);
     `environment` → escalate, don't reconfigure.
4. **GATE & CLOSE.** On a PASS, dispatch `reviewer` on the diff to confirm the test
   asserts something real (the charter spine). `ship` → `bd close`. A `fix-first`
   flagging a hollow/weakened test is a HARD HALT; any other `fix-first` loops back
   to the builder.
5. At the TOP of each pass, fold in any open interjection beads (`bd list --label
   interjection`, close each). Run
   the watchdog: a pass with zero beads closed AND zero new beads filed is
   no-progress — halt at K=3 consecutive, or MAX_PASSES=50. Emit a Seance event
   per lifecycle step.
6. Report: beads closed (tests landed), still open, anything you stopped on, and
   any product bugs the runner surfaced.

For runs longer than one session, re-enter with `/loop` or the ralph-loop plugin —
state survives in beads + git.
