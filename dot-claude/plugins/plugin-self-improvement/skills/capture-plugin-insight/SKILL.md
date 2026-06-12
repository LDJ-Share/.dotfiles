---
name: capture-plugin-insight
description: Use the INSTANT you have a realization, epiphany, light-bulb, or "aha" moment about the Claude Code plugin collection ITSELF — or notice a plugin/skill/command/agent is wrong, slow to reach the answer, missing, duplicated, or contradicts how things actually work. Captures the insight as a tracked plugin-improvement bead (filed under the self-improvement epic bead) so it isn't lost in the moment it occurs. Triggers on meta-insights about improving/correcting/reinforcing/extending these plugins — NOT on ordinary task work.
---

# Capture a plugin-improvement insight (beads backend)

The best ideas for improving the plugins arrive mid-task — a moment where you
realize "this skill should have told me X," or "this instruction is wrong," or
"there should be a plugin for this." Those moments evaporate. This skill exists to
**catch them and file them** without derailing what you're doing.

## When this fires

Fire when you notice ANY of these about the plugin collection (not the current
task's code):

- **Improve** — a skill/command/agent could be clearer, faster, or more reliable.
- **Correct** — an instruction is wrong, stale, or buggy.
- **Reinforce (shortcut to the answer)** — you reached a good answer the slow way;
  a pointer/example baked into a skill would get there faster next time.
- **Contradiction with reality** — a plugin claims something the environment
  disproves (a flag that doesn't exist, a path that moved, a tool that behaves
  differently). These are the highest-value catches.
- **New plugin** — a recurring need has no home plugin.
- **Consolidate** — the same rule is duplicated across files and should be unified.
- **Anything adjacent** — gaps, missing safety nets, confusing names, dead wiring.

## Is it worth capturing? (30-second filter)

File it only if it's **durable + actionable + about the plugins**:

- Durable: it'll still be true next session (not a one-off quirk of this task).
- Actionable: there's a concrete change someone could make.
- About the plugins: it improves the collection, not just this repo's code. (Repo
  code → that's normal work, not this skill. A *real* bug in the current repo →
  file it the normal way, not here.)

If it fails the filter, drop it and continue. Don't over-capture — noise buries
signal.

## Classify it

Tag the insight with ONE primary reason from the taxonomy above
(improve / correct / reinforce / contradiction / new-plugin / consolidate / other)
— put it in the bead body so the backlog is triageable.

## One-time setup (the epic bead)

Self-improvement beads are filed under ONE long-lived **epic bead** carrying the
`plugin-self-improvement` label. Create it once, in the beads database you use for
plugin/meta work (server-mode or a dedicated hub repo — NOT a throwaway
`--stealth` work-repo db, since this is long-term filing):

```bash
bd create "Plugin self-improvement (continuous)" -t epic -l plugin-self-improvement
```

The skill discovers it by label, so you never hard-code its id.

## File it (one bead per insight)

1. **Find the epic:** `bd list -l plugin-self-improvement --json` → note its id
   (`<epic-id>`). If none exists, do the one-time setup above first.
2. **Dedup:** `bd list -l plugin-improvement --json` (open + recently closed) — if a
   near-duplicate exists, comment on it (`bd update`) instead of filing a new bead.
3. **Create the bead** labeled `plugin-improvement`:
   `bd create "<title>" -t <task|feature> -l plugin-improvement`
   Title = a crisp one-liner naming the plugin + the change
   (e.g. "orchestrator: reviewer-gate should also flag deleted [InlineData]").
4. **File it under the epic:** `bd dep add <new-id> <epic-id>` (records it as part of
   the self-improvement epic).
5. **Body — use this structure so the backlog is consistent:**
   ```
   Insight:        <what you realized, in 1–3 sentences>
   Reason:         <improve | correct | reinforce | contradiction | new-plugin | consolidate | other>
   Affected:       <plugin(s) / skill / command / agent / file, if known>
   Proposed change: <the concrete edit or addition>
   Evidence:       <what made this obvious — the error, the slow path, the contradiction>
   Captured from:  <repo @ branch, or the task you were doing>
   ```
6. **Leave it open at its default state.** This skill only *captures* — triage and
   execution happen later through the normal orchestrator flow. Don't implement now.

## Don't derail

This is a drive-by capture, exactly like filing a discovered bead or a `/notify`
interjection: file the bead, note its id in one line, and **return to what you were
doing**. Do NOT pivot the current task into implementing the improvement unless the
human asks.

## Relationship

This is the **beads-backed** variant (files beads under the `plugin-self-improvement`
epic bead). The **ADS-backed** counterpart in the matt-plugins marketplace files
User Stories under Feature #310 instead. Same discipline, different store.
