---
description: Capture an explicit plugin-improvement insight as a tracked bead under the self-improvement epic bead. The deliberate counterpart to the aha-triggered capture-plugin-insight skill.
argument-hint: <your insight about how a plugin could be improved/corrected/extended>
---

# /improve-plugin — file a plugin-improvement insight (beads)

The human (or you) has an explicit idea for improving the Claude Code plugin
collection. Capture it as a bead so it isn't lost. This is the deliberate sibling of
the `capture-plugin-insight` skill — invoke that skill for the full discipline; this
command is the fast, explicit entry point.

## Do this

1. Take the full argument text as the insight. If empty, ask the human what to
   capture (which plugin, what change).
2. Invoke the **`capture-plugin-insight`** skill and follow it: apply the worth-it
   filter, classify the reason, find the epic (`bd list -l plugin-self-improvement
   --json`), **dedup** against existing `plugin-improvement` beads, create ONE bead
   labeled `plugin-improvement`, and `bd dep add` it under the epic — using the
   structured body the skill defines.
3. Confirm to the human: filed bead `<id>` under the self-improvement epic, with its
   title and reason-tag. Leave it at its default state — capture only; don't start
   implementing.

## Notes

- One insight = one bead — keep them atomic.
- If the epic bead doesn't exist yet, do the skill's one-time setup first
  (`bd create "Plugin self-improvement (continuous)" -t epic -l plugin-self-improvement`).
- If a near-duplicate bead already exists, comment on it instead of filing a new one.
- This is the beads entry point; the matt-plugins `/improve-plugin` files an ADS Story
  under Feature #310 instead.
