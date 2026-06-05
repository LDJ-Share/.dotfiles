# Orchestrator template (context-frugal multi-agent + beads)

A drop-in setup for running heavy workflows on a constrained context window
(e.g. Sonnet 4.5 @ 200k) by keeping the main session high-altitude and pushing
all durable state into [beads](https://github.com/steveyegge/beads) + git.

## The idea

The main Claude Code session is an **orchestrator**: it holds almost nothing.
It loops over ready beads, dispatches disposable subagents to do the actual
reading/editing/verifying, and records outcomes back into beads. Real state
lives outside every context window:

- **beads (`.beads/`)** — task graph, status, discovered work, project memory
- **git** — the code and its history

One 200k window becomes *orchestrator + N disposable worker windows*. A worker
can burn 150k reading a subsystem; the orchestrator only ever sees its ~1k
summary, so its window stays clean and compacts (or `/clear`s) for free.

```
Orchestrator (main, Sonnet)  ── bd prime → bd ready → claim → dispatch → record
   │            │              │
 scout      implementer     verifier        (+ optional reviewer)
 (Haiku)     (Sonnet)       (Haiku)
 read-only   one bead's     run tests/
 map         diff           build
   └─── each returns a ~1k structured summary ───┘
```

## Install (on the work machine)

This repo is synced read-only, so **copy** from here into your work repo:

```bash
# from your work repo root
mkdir -p .claude/agents
cp <path-to-this-template>/agents/*.md .claude/agents/

# append the orchestration protocol to your repo's CLAUDE.md
cat <path-to-this-template>/CLAUDE-snippet.md >> CLAUDE.md
```

Then initialize beads locally (no files committed to the work repo):

```bash
bd init --stealth
```

## The contract that makes it work

The orchestrator is **forbidden** from reading files, grepping, or reading long
tool output directly — that's what rots a window. Everything substantive happens
inside a subagent's throwaway context; only bead IDs, one-paragraph summaries,
and pass/fail land in the main session.

## beads write-safety

All beads writes are routed through the orchestrator. Subagents never touch the
db (scout/verifier don't write; the implementer only *reports* discovered work
in its return, and the orchestrator files it). This sidesteps the only real
concurrency hazard: two `bd` processes writing the same `.beads` db at the same
instant. You'd only need to revisit it if you later let subagents write beads
directly **and** dispatch them in parallel from one working directory.

## Tiering

| Agent | Model | Why |
|---|---|---|
| Orchestrator (main) | Sonnet | Fixed constraint; stays near-empty so 200k is plenty |
| scout | Haiku | Search/mapping is mechanical |
| implementer | Sonnet | Needs real reasoning, but in a disposable window |
| verifier | Haiku | Running commands + excerpting failures is cheap |
| reviewer (optional) | Sonnet | Diff review before closing a risky bead |
