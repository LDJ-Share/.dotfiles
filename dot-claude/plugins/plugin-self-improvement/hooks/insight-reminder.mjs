#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// SessionStart reminder for plugin-self-improvement (beads variant).
//
// PURPOSE: A one-line nudge so the model remembers it can capture "aha" moments
//   about the plugin collection as tracked beads. Portable/air-gapped — no ADS org
//   to gate on — so it fires on every session start; kept to a single line.
//
// CONTRACT: prints `hookSpecificOutput.additionalContext` JSON on stdout. ANY
//   failure degrades to no-output (exit 0) — a reminder must never break or slow a
//   session.
// ─────────────────────────────────────────────────────────────────────────────

const REMINDER =
  "💡 plugin-self-improvement: if an 'aha' moment, contradiction, or improvement " +
  "idea about the Claude Code plugins surfaces this session, capture it (don't lose it) " +
  "via the `capture-plugin-insight` skill or `/improve-plugin <insight>` — files a bead " +
  "under the `plugin-self-improvement` epic. Capture and keep going; don't derail the current task.";

try {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: REMINDER,
      },
    }),
  );
} catch {
  // Never break a session over a reminder — fall through to exit 0.
}

process.exit(0);
