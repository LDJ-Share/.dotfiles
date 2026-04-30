---
name: using-superpowers
description: Session-start bootstrap. Tells Claude to check available skills before responding and to invoke brainstorming for any creative work.
---

## Purpose

Session-start bootstrap. Establishes the priority order between user instructions, skills, and default behavior; tells Claude to scan for matching skills before responding; and routes creative work through `brainstorming`.

## Behavior

1. This skill fires at session start, typically via the Claude Code SessionStart hook.
2. **Instruction priority** — apply in this order:
   1. User instructions (CLAUDE.md, GEMINI.md, AGENTS.md, direct messages).
   2. Skills.
   3. Default behavior.
   Skills override defaults but yield to user direction. If a user instruction and a skill conflict, the user wins.
3. Before responding to any user message, scan the available-skills list for matches. If a skill probably applies, invoke it via the Skill tool BEFORE responding — even before clarifying questions.
4. **Creative work routes through `brainstorming`.** Triggers include "let's build X", "design a Y", "how should we approach Z", "redesign the …", and any open-ended new-feature request. Don't skip to implementation.
5. Use TodoWrite to track multi-step plans surfaced during brainstorming or writing-plans.
6. When the user explicitly opts out of a skill's discipline ("just edit the file", "skip the plan"), honor that — user instruction outranks skill defaults.

### See also

- `brainstorming` — the most common downstream invocation.
- `writing-plans` and `executing-plans` — downstream of brainstorming on the design chain.
