---
description: Interject a steering message to a running orchestrator by filing an interjection bead — safe under beads server mode; the loop folds it in at the top of its next pass.
argument-hint: <your message to the orchestrator>
---

# /notify — steer a running orchestrator (beads backend)

Queue the human's message for a running autonomous loop by filing an **interjection
bead**. The orchestrator checks for open interjection beads at the top of each pass,
folds the guidance into its decisions, and closes them (see "Steering an autonomous
run" in `orchestration-protocol`).

Beads run in **server mode**, so a human `bd` write is safe alongside the
orchestrator's — no file-lock contention, no side-channel file needed.

## Do this
1. Take the full argument text as the message. If empty, ask the human what to tell
   the orchestrator.
2. File an interjection bead:
   `bd create "<message>" -l interjection`
   (`-l` labels it; the orchestrator sweeps + closes interjection beads at the top
   of each pass and excludes the label from work selection, so one is never claimed
   as work. If the steer is scoped to one item, name that bead id in the body.)
3. Confirm to the human: filed bead `<id>`; the orchestrator picks up interjection
   beads at the start of each pass and closes them once folded in. Urgent? press
   **Esc** to interrupt the run now instead of waiting.

## Notes
- One message = one bead — keep them atomic (see the atomic-beads guidance).
- The orchestrator **closes** interjection beads (centralized writes / clean audit
  trail); you only create them.
- This is the beads-backend command; the ADS `brain-orchestrator` counterpart files
  the same kind of interjection bead.
