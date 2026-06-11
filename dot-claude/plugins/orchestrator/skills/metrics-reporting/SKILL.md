---
name: metrics-reporting
description: Use when generating an orchestration metrics report (e.g. via /gather-metrics) on a beads-backed run — pins the canonical data sources, the standard metric set + formulas, and the deterministic markdown output schema so every report is consistent and comparable over time. The realization of the Seance log's metrics.
---

# Orchestration metrics reporting (canonical, beads backend)

The point of this skill is **consistency**. Ad-hoc "give me some metrics" prompts
produce a different shape every time, which makes runs impossible to compare. This
pins ONE schema: compute exactly the metrics below, in exactly the output shape
below, every time. Same headings and columns even when a value is `n/a`.

## Sources
- **Seance event log** — `.orchestrator/events.jsonl`, one JSON line per lifecycle
  event (`create / claim / verify / review / close / reopen / interject / discovery /
  blocked / escalation`), with fields `ts, session, bead, actor, kind, result,
  verdict, reason, tokens, what, why, files`. This is the PRIMARY source. (If the
  project runs beads in server mode, query native bd events instead of the file.)
- **bd state** — current type / status / priority for the items in range
  (`bd show`, `bd list`).
- **git log** — commit + merge counts in the window
  (`git log --since=<start> --until=<end> --oneline`).
- **interjection beads** — `bd list --label interjection --all` (open + closed in
  window) for the human-steering count; beads run in server mode.

Read these inside this reasoning step and summarize as you go — never dump raw logs
into context.

## The canonical metric set
Compute each. Show `n/a` (not `0`) when the source genuinely lacks the data.

**Throughput** — items closed; items created; discovered-work filed; net open delta.

**Loop health** — passes run; watchdog halts / escalations; avg passes per closed item.

**Quality**
- Reviewer-gate catch rate = `review:fix-first ÷ total reviews`.
- Rework rate = `reopens ÷ closes`.
- Verifier first-pass rate = `items whose first verify was pass ÷ items`.

**Flow** — cycle time per item = `close.ts − claim.ts`; report **median + p90**.

**Cost** — tokens per closed item (from `close.tokens`); report **median + total**.

**Steering** — interjections (interjection beads filed via `/notify`) in window; needs-review count.

## Output schema (write this shape verbatim)

```
# Orchestration metrics — <scope label>

- Generated:   <ISO-8601>
- Backend:     beads
- Repo:        <repo name> @ <branch>
- Window:      <resolved start>..<resolved end>
- Sessions:    <ids or count>
- Source:      .orchestrator/events.jsonl (<N> events)

## Summary
| Metric | Value |
|---|---|
| Items closed | … |
| Items created | … |
| Discovered-work filed | … |
| Net open delta | … |
| Passes run | … |
| Watchdog halts | … |
| Avg passes / item | … |
| Reviewer-gate catch rate | …% (fix-first/total) |
| Rework rate | …% (reopens/closes) |
| Verifier first-pass rate | …% |
| Cycle time (median / p90) | … / … |
| Tokens / item (median) | … |
| Total tokens | … |
| Interjections | … |
| needs-review | … |

## Per-item
| Item | Type | Passes | Cycle | Tokens | Verdict |
|---|---|---|---|---|---|
| … | … | … | … | … | … |

## Notes
- <2–5 bullets: notable stalls, the costliest item, any halt + reason, data gaps.>
```

## Rules
- **Deterministic shape.** Same headings + columns every run, even when values are
  `n/a`. This is what makes reports comparable.
- **Never fabricate.** If a field's source is absent, write `n/a` and call out the
  gap in Notes.
- **Read-only.** Computing metrics must not mutate beads or advance any item.
- **Output path.** Default `./metrics/`; filename `metrics/<YYYY-MM-DD>-<scope>.md`;
  never overwrite (suffix `-2`, `-3`, …).
