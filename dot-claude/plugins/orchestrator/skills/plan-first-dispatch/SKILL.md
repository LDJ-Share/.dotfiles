---
name: plan-first-dispatch
description: Use before implementing any non-trivial bead — establishes the "always plan first, model approves" discipline for the beads orchestrator. The orchestrator dispatches a read-only planner agent, persists the returned plan, auto-approves it (bounded by the charter's hard-halts — NOT a rubber stamp), then hands the approved plan to the implementer. Flat dispatch (subagents can't nest); the durable plan artifact is the context win.
---

# Plan-first dispatch (model-approved planning) — beads backend

We do better work when we plan first — but planning gets skipped, and when a plan IS
produced it's usually right. So make it automatic: every non-trivial bead gets a plan,
the ORCHESTRATOR approves it (no human plan-approval pause), and the approved plan
drives the implementer.

## The flow (flat — this is the only viable shape)
Subagents cannot spawn subagents, so there is no live "sub-orchestrator → planner →
implementer" chain. YOU (the main-loop orchestrator — the only context with the Agent
tool) run a FLAT pipeline:

1. **Plan.** Dispatch the `planner` agent (read-only, `permissionMode: plan`) with the
   bead ID + acceptance criteria + scout map. It returns a compact plan: Goal, Steps,
   Blast radius, Risks, Recommendation.
2. **Persist.** Write the plan to a DURABLE artifact, not your window — the bead body /
   a comment (or a plan file for a big item). Keep only the plan's location + its
   Recommendation line in context. This is the context win — and it's *better* than a
   sub-orchestrator, which would still hold the plan in some window.
3. **Approve (bounded).** Apply the boundary below. If it passes, approve and continue;
   if not, STOP and report.
4. **Implement.** Dispatch `implementer` pointed at the persisted plan artifact (hand
   it the plan, don't make it re-derive). Then `verifier` → reviewer → close, as usual.

## Auto-approval boundary (NOT a rubber stamp)
Auto-approval replaces the "is this plan OK?" PROMPT — it does NOT replace the
stop-conditions. Approve the plan yourself ONLY if the planner's Blast radius is clean
and its Recommendation is `proceed`. You MUST instead STOP and report (do not
auto-approve) if the plan entails any charter hard-halt:
- a public API / contract / DTO / on-disk-or-wire-format change;
- weakening, skipping, or deleting a test or assertion;
- build-infra / config edits (build files, lockfiles, migrations, app config, CI);
- scope beyond the bead; or
- ANY uncertainty (the planner recommended `needs-review`, or you're not confident).

Automated planning removes the routine approval click, never the safety architecture.
A risky plan is surfaced to the human exactly as before — this is the SAME gate the
reviewer enforces, applied one step earlier.

## When to skip planning
Don't over-plan. A truly trivial, single-file, obviously-correct change (a typo, a
one-line fix, a doc tweak) can go straight to the implementer. Plan when there's more
than one reasonable approach, multiple files, or any blast-radius question.

## Where this runs
YOU run this in the main loop; `planner`/`implementer` are leaf agents. It must stay
orchestrator-facing — a subagent that loaded this skill could NOT dispatch the planner
(no Agent tool inside a subagent). Referenced by `orchestration-protocol` (the Loop),
`/implement`, and dev-workflow's `/execute`.
