
## Orchestration protocol (context-frugal)

You are an ORCHESTRATOR. Your context window is a small scratchpad, not storage.
Durable state lives in beads (`.beads/`) and git. Keep yourself high-altitude.

### Hard rules
- Do NOT Read files, Grep, Glob, or run builds yourself. Delegate to a subagent.
- The only things allowed in your window: bead IDs, ≤1-paragraph summaries,
  pass/fail, and diffs you must review. If a tool would dump >50 lines, a
  subagent should run it and summarize instead.
- One bead in flight at a time unless they're truly independent.

### Loop
1. Session start: run `bd prime` (workflow context + memories), then
   `bd ready --json` to see actionable work.
2. Pick the highest-priority ready bead. Claim it: `bd update <id> --claim`.
3. If the area is unfamiliar, dispatch `scout` with the bead. It returns a map
   (files, symbols, entry points) — you do NOT read those files yourself.
4. Dispatch `implementer` with: the bead ID, acceptance criteria, and scout's map.
   It makes the change in its own context and returns a summary + discovered work.
5. Dispatch `verifier` to run tests/build. It returns pass/fail + failure excerpts.
6. On green:
   - `bd close <id> "<one-line outcome>"`
   - File each discovered item: `bd create "<title>" -t <type> -p <pri>`,
     then `bd dep add <new-id> <id>` (records it as discovered-from this bead).
   - Capture any durable lesson: `bd remember "<insight>"`.
7. `/clear` (or just continue). Clearing is free — state is in beads + git.

### Centralized beads writes
Subagents do NOT touch beads. They REPORT discovered work in their return; YOU
file it. This keeps the audit trail in one place and avoids simultaneous writers
on the local `.beads` db.

### Watchdog (no-progress halt)
Loop-global liveness guard for autonomous runs. Track progress per loop pass —
progress = ≥1 bead closed OR ≥1 new bead filed that pass. HALT and report if `K`
consecutive passes make ZERO progress, or if total passes hit `MAX_PASSES`
(backstop). On halt, emit a Seance event (`kind=escalation`) reporting passes
run, beads closed, and the halt reason. Two knobs: `K` (consecutive no-progress
passes, default 3); `MAX_PASSES` (default 50). This is loop-global liveness —
distinct from the charter's per-bead "3 consecutive verifier FAILs" and from any
per-run beads-closed checkpoint cap. Full rule: PATTERNS.md.

### Steering an autonomous run (interjection)
The human can add information mid-run without breaking anything — all state lives
in beads + git, so interrupting and resuming is lossless.
- **Non-urgent:** the human appends to `.orchestrator/inbox.md`. At the TOP of
  each loop iteration, read it; if non-empty, fold the guidance into your
  decisions, then archive it (append to `.orchestrator/inbox.archive.md` and
  truncate the inbox). Human only writes the inbox; you only read + clear it —
  no contention.
- **Urgent:** the human presses Esc to interrupt. Take their input, then resume
  by re-reading `bd ready` — nothing is lost.
- The human should NOT interject by running `bd` themselves (see Beads safety).

### Beads safety (avoid hangs/deadlocks)
- ONE writer at a time. Subagents never write beads; humans steer via the inbox,
  not `bd`. Two `bd` processes writing the same `.beads` db can lock and hang.
- For UNATTENDED runs, `bd` and your test/build commands MUST be in the Claude
  Code permission allowlist — otherwise the loop silently blocks on an approval
  prompt and looks like a deadlock.
- Use non-interactive `bd` (e.g. `--json`, any `--yes`/no-prompt flag); a `bd`
  command waiting on stdin will hang a non-interactive shell.
- If a `bd` call hangs: abort it, check for a stale lock file in `.beads/`, retry
  once. If it persists, STOP and report — do not loop on it.

### Seance: decision log (durable agent memory)
Keep a queryable trail of WHY decisions were made so future agents — and you,
after a compaction or `/clear` — recover context without re-deriving it.

Baseline (portable): append one JSON line per closed bead or notable decision to
`.orchestrator/events.jsonl`:
  `{"ts":"<ISO8601>","bead":"<id>","actor":"<agent>","kind":"decision|outcome|discovery|blocked|escalation","what":"<one line>","why":"<one line>","files":["..."]}`
ONLY the orchestrator appends (centralized — avoids concurrent-append corruption);
it has each subagent's structured return, so it writes the line from that. At
session start, read the tail of this file alongside `bd prime`; when reasoning
about an area, grep it for prior decisions on those files/beads.

On beads (durable/shared upgrade): use native events instead of the file —
`bd create --type event --event-category <kind> --event-actor <agent>
--event-target <bead-id> --event-payload '{"what":...,"why":...}' --ephemeral`.
Routine events TTL-compact; record lasting calls as `--type decision` (permanent).
Native events are queryable via `bd` and shared across machines in server mode.
