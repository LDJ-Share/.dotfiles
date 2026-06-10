# orchestrator (context-frugal multi-agent + beads)

A plugin for running heavy workflows on a constrained context window (e.g. Sonnet
4.5 @ 200k) by keeping the main session high-altitude and pushing all durable state
into [beads](https://github.com/steveyegge/beads) + git.

## The idea

The main Claude Code session is an **orchestrator**: it holds almost nothing. It
loops over ready beads, dispatches disposable subagents to do the actual
reading/editing/verifying, and records outcomes back into beads. Real state lives
outside every context window:

- **beads (`.beads/`)** — task graph, status, discovered work, project memory
- **git** — the code and its history

One 200k window becomes *orchestrator + N disposable worker windows*. A worker can
burn 150k reading a subsystem; the orchestrator only ever sees its ~1k summary, so
its window stays clean and compacts (or `/clear`s) for free.

```
Orchestrator (main, Sonnet)  ── bd prime → bd ready → claim → dispatch → record
   │            │              │
 scout      implementer     verifier        (+ optional reviewer)
 (Sonnet)    (Sonnet)       (Sonnet)
 read-only   one bead's     run tests/
 map         diff           build
   └─── each returns a ~1k structured summary ───┘
```

## Contents

| Kind | Names |
|---|---|
| **skill** | `orchestration-protocol` — the loop, centralized beads writes, watchdog, inbox steering, beads safety, the Seance decision log (+ a `patterns` reference for fan-out / autonomous-drain) |
| **commands** | `/implement` (decompose + build a task/feature), `/triage` (recover a failing suite), `/cover` (.NET coverage) |
| **agents** | `scout` · `implementer` · `verifier` · `reviewer` · `investigator` · `test-writer` |

Each command invokes the `orchestration-protocol` skill for the shared contract,
then layers its own decision charter on top. See `skills/orchestration-protocol/`.

## The contract that makes it work

The orchestrator is **forbidden** from reading files, grepping, or reading long
tool output directly — that's what rots a window. Everything substantive happens
inside a subagent's throwaway context; only bead IDs, one-paragraph summaries, and
pass/fail land in the main session.

## Tiering

| Agent | Model | Why |
|---|---|---|
| Orchestrator (main) | Sonnet | Fixed constraint; stays near-empty so 200k is plenty |
| scout | Sonnet | Mapping is mechanical (a natural haiku-tier task) |
| implementer | Sonnet | Needs real reasoning, but in a disposable window |
| verifier | Sonnet | Running commands + excerpting is cheap (a natural haiku-tier task) |
| reviewer | Sonnet | Diff review before closing a risky bead |
| investigator | Sonnet | Root-causes one bug read-only; reasoning-heavy |
| test-writer | Sonnet | Writes tests for one unit in isolation |

> **All workers ship on Sonnet.** The model column shows the *natural* tier, but
> the agents are hard-set to `sonnet`: Claude Code has no per-agent fallback model,
> and the target environments' haiku model may lack prompt caching. Where haiku
> caching is available, `scout` and `verifier` can safely drop back to `haiku`.

## Setup in a work repo

1. Install the plugin (it ships in the dotfiles `dot-claude/.claude-plugin`
   marketplace). The skill + agents + commands are then available globally.
2. Initialize beads locally (no files committed to the work repo):
   ```bash
   bd init --stealth
   ```
3. **Allowlist `bd` and your test/build commands** in `settings.json` before an
   unattended run — otherwise the loop blocks on an approval prompt and looks like
   a deadlock.
4. **gitignore** `.orchestrator/` (transient steering scratch, not state).

## Running autonomously: steering & safety

- **Interject info** any time by appending to `.orchestrator/inbox.md`; the
  orchestrator reads + clears it at the top of each loop pass. For an urgent
  course-correction, press **Esc** — state lives in beads + git, so interrupting
  and resuming loses nothing. Don't interject by running `bd` yourself.
- One beads writer at a time; if a `bd` call hangs, check for a stale lock in
  `.beads/`. See "Beads safety" in the `orchestration-protocol` skill.
- **Decision log (Seance):** the orchestrator appends one JSON line per closed bead
  to `.orchestrator/events.jsonl` (or native beads events on server mode) so future
  sessions recover *why* without re-deriving. See "Seance" in the skill.

## Relationship to brain-orchestrator

This is the portable, **ADS-agnostic** counterpart of the `brain-orchestrator`
plugin (in the `matt-plugins` marketplace), which drives Azure DevOps Boards
instead of beads. Same loop, same worker roster; different state backend.
