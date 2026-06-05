
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
