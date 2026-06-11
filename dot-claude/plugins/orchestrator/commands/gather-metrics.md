---
description: Generate a consistent, structured orchestration metrics report for a timeframe and write it to ./metrics/. Reads the Seance event log; uses the metrics-reporting skill's canonical schema so every report is comparable.
argument-hint: [today | this session | <YYYY-MM-DD>..<YYYY-MM-DD> | feature <id> | all] [--out <dir>]
---

# /gather-metrics — structured orchestration metrics

Produce a deterministic metrics report for an orchestration run (or a window of
runs) and write it as markdown under `./metrics/`.

**First invoke the `metrics-reporting` skill** — it defines the canonical data
sources, the metric set + formulas, and the exact output schema. This command is
just the trigger; the skill is the contract that keeps every report identical in
shape so they're comparable over time (the whole point — ad-hoc metric prompts
drift in format every run).

## Steps
1. **Parse the timeframe** from the argument (default: `this session`):
   - `today` → events dated today (local).
   - `this session` → events for the current session id.
   - `<YYYY-MM-DD>..<YYYY-MM-DD>` → inclusive date range.
   - `feature <id>` / `for <id>` → events whose items trace to that feature/epic.
   - `all` → the whole log.
   `--out <dir>` overrides the output directory (default `./metrics/`).
2. **Gather** per the `metrics-reporting` skill (beads backend): read
   `.orchestrator/events.jsonl` (the Seance log), `bd` state for the items in range,
   `git log` for commit/merge counts in the window, and interjection beads
   (`bd list --label interjection --all`) for the steering count. Summarize as you read —
   never dump raw logs into context.
3. **Compute** the canonical metric set (the skill lists each metric + its formula).
4. **Write** the report to `./metrics/<YYYY-MM-DD>-<scope>.md` (create `metrics/`
   if missing) using the skill's output schema. Never overwrite — suffix `-2`, `-3`.
5. **Print** the written path as a clickable `file://` URI plus a 3-line summary.

## Notes
- If `.orchestrator/events.jsonl` is missing or empty, say so and fall back to
  whatever `bd` history can provide; never fabricate numbers — write "n/a" and note
  the gap.
- Read-only with respect to orchestration state: gathering metrics must not write
  beads or advance any item.
