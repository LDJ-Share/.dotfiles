---
name: brainstorming
description: For creative work (new features, designs, redesigns). Explore intent through one-question-at-a-time dialogue; produce a spec doc for downstream planning.
---

## Purpose

Front-load the design conversation before any code is written. One clarifying question at a time, multiple-choice when possible, approval-gated sections. The output is a spec document the downstream `writing-plans` skill consumes.

## Behavior

1. Run this skill before any creative-work substantive output. Creative work means: new features, redesigns, "let's build X", "how should we approach Y".
2. Explore project context first — relevant files, recent commits, related docs — so questions are informed, not generic.
3. Ask clarifying questions ONE AT A TIME. Multiple-choice when possible (lower cognitive cost than open-ended).
4. After enough context, propose 2–3 approaches with tradeoffs. Recommend one explicitly with reasoning.
5. Present the design in approval-gated sections (architecture, components, behaviors, etc.). Get explicit approval per section before moving on.
6. Decompose if scope is too large for a single spec. Surface the decomposition before going deep on any sub-project.
7. Save the spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` using today's date.
8. Self-review the written spec: any placeholders, contradictions, scope-creep, ambiguity? Fix inline.
9. Ask the user to review the written spec before transitioning.

### When NOT to use

- Trivial fixes — single-line bugs, typos.
- Routine commits.
- Debug investigations.

These don't need brainstorming overhead. Brainstorming on a typo wastes the user's time.

### Next step (required)

After the user approves the written spec, invoke `writing-plans` to convert it into a tactical implementation plan. State the hand-off explicitly — don't imply it.

### See also

- `writing-plans` — the mandatory next step after spec approval.
- `using-superpowers` — the bootstrap that triggers this skill for creative work.
