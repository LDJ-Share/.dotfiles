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
mkdir -p .claude/agents .claude/commands
cp <path-to-this-template>/agents/*.md .claude/agents/
cp <path-to-this-template>/commands/*.md .claude/commands/

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
| investigator | Sonnet | Root-causes one bug read-only; reasoning-heavy |
| test-writer | Sonnet | Writes tests for one unit in isolation |

## Workflows

Two fan-out workflows ship as slash commands (see `PATTERNS.md` for the
underlying parallel-fan-out and autonomous-drain patterns):

- **`/triage [filter]`** — autonomously triage a failing/buggy integration suite:
  fan out read-only `investigator`s, file fix beads, then drain them through
  `implementer` + `verifier` until green or a stop-condition trips. Ships a
  conservative .NET decision charter in `commands/triage.md` — review and tune
  its three knobs (flaky re-runs, consecutive-fail limit, bead checkpoint).
- **`/cover [path]`** — parallelize unit-test coverage: decompose into per-unit
  beads, fan out `test-writer`s on disjoint files, verify, drain. Routes through
  the `dotnet-test` skills automatically on .NET repos.

## Running autonomously: steering & safety

- **Interject info** any time by appending to `.orchestrator/inbox.md`; the
  orchestrator reads + clears it at the top of each loop pass. For an urgent
  course-correction, press **Esc** — state lives in beads + git, so interrupting
  and resuming loses nothing. Don't interject by running `bd` yourself.
- **Allowlist `bd` and your test/build commands** in `settings.json` before an
  unattended run — otherwise the loop blocks on an approval prompt and looks
  like a deadlock.
- **gitignore** `.orchestrator/` (it's transient steering scratch, not state).
- One beads writer at a time; if a `bd` call hangs, check for a stale lock in
  `.beads/`. See "Beads safety" in `CLAUDE-snippet.md`.
