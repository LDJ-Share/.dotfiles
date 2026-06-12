---
name: orchestration-protocol
description: Use when running a context-frugal autonomous orchestration session backed by beads (bd) + git — establishes the high-altitude loop, centralized beads writes, the watchdog, interjection steering, beads safety, and the Seance decision log. Invoke before /implement, /triage, or /cover. Sized for a Sonnet-4.5 / 200k orchestrator.
---

# Orchestration protocol (context-frugal)

You are an ORCHESTRATOR. Your context window is a small scratchpad, not storage.
Durable state lives in beads (`.beads/`) and git. Keep yourself high-altitude —
this is what lets a single Sonnet-4.5 / 200k window run a long autonomous loop.

## Hard rules
- Do NOT Read files, Grep, Glob, or run builds yourself. Delegate to a subagent.
- The only things allowed in your window: bead IDs, ≤1-paragraph summaries,
  pass/fail, and diffs you must review. If a tool would dump >50 lines, a
  subagent should run it and summarize instead.
- One bead in flight at a time unless they're truly independent.

## Lean on the dotnet skills for .NET specifics
When a subtask is .NET-specific — a red build, running or **filtering** tests,
coverage, a test-framework/platform question, a package or framework migration, a
perf investigation — prefer the installed **dotnet-agent-skills**
([dotnet/skills](https://github.com/dotnet/skills)) over reasoning from memory.
Dispatch the matching **agent** so the heavy work stays in an isolated context
(`dotnet-msbuild:msbuild` for build failures, `dotnet-test:code-testing-tester` for
running tests, `dotnet-diag:optimizing-dotnet-performance` for perf), or — for a quick
lookup — invoke the **skill** (`dotnet-test:run-tests`, `dotnet-test:filter-syntax`,
`dotnet:csharp-scripts`). If the marketplace isn't installed, proceed normally; this
is an accelerator, not a hard dependency (see the README's "Recommended additional
skills" for the install line + which plugins to add).

## Loop
1. Session start: run `bd prime` (workflow context + memories). Then **sweep
   interjections**: `bd list --label interjection --json` — fold each into your
   plan and `bd close` it (these are human steers via `/notify`, not work). Now see
   actionable work: `bd ready --json --exclude-label interjection`.
2. Pick the highest-priority ready bead. Claim it: `bd update <id> --claim`. (Never
   claim an `interjection`-labeled bead — they're swept in step 1 and excluded from
   the ready query.)
3. If the area is unfamiliar, dispatch `scout` with the bead. It returns a map
   (files, symbols, entry points) — you do NOT read those files yourself.
3a. **Plan first** for non-trivial beads (see `plan-first-dispatch`): dispatch
   `planner` (read-only), persist the returned plan, and auto-approve it *bounded by
   the charter* — a plan that would trip a hard-halt → STOP and report, not approve.
   Trivial one-file changes may skip straight to step 4.
4. Dispatch `implementer` with: the bead ID, acceptance criteria, scout's map, and the
   approved plan. It makes the change in its own context and returns a summary +
   discovered work.
5. Dispatch `verifier` to run tests/build. It returns pass/fail + failure excerpts.
6. On green:
   - `bd close <id> "<one-line outcome>"`
   - File each discovered item: `bd create "<title>" -t <type> -p <pri>`,
     then `bd dep add <new-id> <id>` (records it as discovered-from this bead).
   - Capture any durable lesson: `bd remember "<insight>"`.
7. `/clear` (or just continue). Clearing is free — state is in beads + git.

## Centralized beads writes
Subagents do NOT touch beads. They REPORT discovered work in their return; YOU
file it. This keeps the audit trail in one voice; with beads in server mode the
simultaneous-writer hazard is gone, so centralization is now a clarity convention,
not a hard safety requirement.

## Atomic beads (prefer small over coarse)
Bias toward MANY small, atomic beads over a few broad ones. One bead = one
verifiable outcome — a single test turned green, one function extracted, one call
site migrated, one edge case handled. Atomic beads keep the graph honest: per-pass
progress is visible, the watchdog can actually detect a stall, `bd dep` edges are
precise, and a failed bead has a small blast radius. When a bead turns out to hold
two or more independent outcomes, SPLIT it — close or relabel the original and
`bd create` the pieces, wiring `bd dep add` to preserve parentage. File discovered
work the same way: one bead per item, never a grab-bag. Beads are cheap and
disposable — that's the whole point; spend them freely to keep each one atomic.

## Watchdog (no-progress halt)
Loop-global liveness guard for autonomous runs. Track progress per loop pass —
progress = ≥1 bead closed OR ≥1 new bead filed that pass. HALT and report if `K`
consecutive passes make ZERO progress, or if total passes hit `MAX_PASSES`
(backstop). On halt, emit a Seance event (`kind=escalation`) reporting passes
run, beads closed, and the halt reason. Two knobs: `K` (consecutive no-progress
passes, default 3); `MAX_PASSES` (default 50). This is loop-global liveness —
distinct from the charter's per-bead "3 consecutive verifier FAILs" and from any
per-run beads-closed checkpoint cap. Full rule: [references/patterns.md](references/patterns.md).

## Context checkpointing (proactive compaction)
Durable state lives in beads + git, so compaction is cheap — losing your window loses
almost nothing. When you pause to checkpoint (the per-run close cap, or when context
usage runs high, ~70–80%), DON'T wait to be asked. Proactively hand the human two
ready-to-use blocks:

1. A custom **`/compact`** that preserves only the orchestration essentials, e.g.:
   `/compact Keep: open bead IDs + their states, the in-flight bead and its exact
   next step, the charter + stop-conditions, the Seance/events tail, and any result
   not yet written to beads. Drop: closed-item detail, raw tool/build output, file
   contents, resolved sub-threads.`
   Tailor "Keep" to what's actually in flight this run.
2. A **kickoff prompt** to paste in the fresh window once compaction finishes, so the
   next session re-orients from durable state rather than memory, e.g.:
   `Resume the orchestration run per orchestration-protocol. Run bd ready, confirm
   bead <id> is at <state / next step>, and continue the loop. Stop-conditions
   unchanged.`

Present both unprompted; the human accepts and moves on.

## Steering an autonomous run (interjection)
The human can add information mid-run without breaking anything — all state lives
in beads + git, so interrupting and resuming is lossless.
- **Non-urgent:** the human files an **interjection bead** via **`/notify
  <message>`** (a bead labeled `interjection`). At the TOP of each loop iteration,
  query open interjection beads (`bd list --label interjection --json`), fold the
  guidance into your decisions, then `bd close` each. Beads run
  in server mode, so the human's `bd create` is safe alongside your writes — no
  contention, and the steer is durable + queryable rather than a transient file.
- **Urgent:** the human presses Esc to interrupt. Take their input, then resume
  by re-reading `bd ready` — nothing is lost.

## Beads safety
- Beads run in **server mode**, so concurrent writers are safe — the human can
  `/notify` (file an interjection bead) without the file-lock hangs that
  single-writer local-file mode risks. You still keep writes **centralized** by
  convention (you file discovered work + close items) for a clean, one-voice audit
  trail; subagents REPORT, they don't write.
- Read-only workers (scout/investigator/verifier/reviewer) never write state: they
  have no Edit/Write tools, and any `bd` they run must use `bd --readonly --sandbox`.
  For hard enforcement, deny `bd` writes for these agents in settings.
- For UNATTENDED runs, `bd` and your test/build commands MUST be in the Claude
  Code permission allowlist — otherwise the loop silently blocks on an approval
  prompt and looks like a deadlock.
- Use non-interactive `bd` (e.g. `--json`, any `--yes`/no-prompt flag); a `bd`
  command waiting on stdin will hang a non-interactive shell.
- If a `bd` call hangs: abort it, check for a stale lock file in `.beads/`, retry
  once. If it persists, STOP and report — do not loop on it.

## Seance: decision log (durable agent memory)
Keep a queryable trail of WHY decisions were made so future agents — and you,
after a compaction or `/clear` — recover context without re-deriving it.

Baseline (portable): append one JSON line per lifecycle event to
`.orchestrator/events.jsonl`:
  `{"ts":"<ISO8601>","session":"<id>","bead":"<id>","actor":"<agent>","kind":"<see below>","result":"pass|fail","verdict":"ship|fix-first","reason":"<e.g. weakening>","tokens":<int>,"what":"<one line>","why":"<one line>","files":["..."]}`
  kinds: `create, claim, verify, review, close, reopen, interject, decision, discovery, blocked, escalation`. Optional fields apply per kind (result→verify; verdict/reason→review; tokens→close).
ONLY the orchestrator appends (centralized — avoids concurrent-append corruption);
it has each subagent's structured return, so it writes the line from that.

Emit an event at EACH step — create / claim / verify(result) / review(verdict,reason)
/ close(tokens if known) / reopen / interject — not just on close. These power the
metrics (reviewer-gate catch rate, rework rate, cycle time, interjections-per-task,
tokens-per-item); compute them with the **`/gather-metrics`** command (canonical
sources + metric set + output schema live in the `metrics-reporting` skill). At session start, read
the tail of this file alongside `bd prime`; grep it for prior decisions on the
files/beads you touch.

On beads (durable/shared upgrade): use native events instead of the file —
`bd create --type event --event-category <kind> --event-actor <agent>
--event-target <bead-id> --event-payload '{"what":...,"why":...}' --ephemeral`.
Routine events TTL-compact; record lasting calls as `--type decision` (permanent).
Native events are queryable via `bd` and shared across machines in server mode.
