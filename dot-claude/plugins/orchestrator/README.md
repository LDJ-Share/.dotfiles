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

## Recommended permissions

An unattended loop **deadlocks on the first approval prompt** unless you
pre-authorize `bd` + your build/test commands (see "Setup in a work repo" above and
"Beads safety" in the skill). These tiers turn that advice into copy-pasteable
config. Drop one into the repo's `.claude/settings.json` under `permissions`, and
keep the **safety-net deny** no matter which tier you pick. Rules evaluate
**deny → ask → allow** and *deny always wins*, so the net holds across tiers — and
because worker subagents run under these same settings, it protects them too.

Pick a tier by trust × autonomy:

- **Low risk** — your own repo, fully unattended drain. Broad allow, almost no prompts.
- **Medium risk** *(default)* — supervised; auto-runs the loop + build/test but **asks** before `git commit`/`push`.
- **High risk** — untrusted/shared repo; read-only + build/test by default, **asks** on every `bd` write and git mutation.

### Safety-net deny — include in EVERY tier

Blocks secrets/credentials and the most destructive shell regardless of tier.
`Edit` governs all file writes (there is no separate `Write` domain), so secrets
get both a `Read` and an `Edit` deny; `curl`/`wget` are denied because `WebFetch`
rules alone don't stop shell egress.

```json
{
  "permissions": {
    "deny": [
      "Read(.env)", "Edit(.env)",
      "Read(.env*)", "Edit(.env*)",
      "Read(**/secrets/**)", "Edit(**/secrets/**)",
      "Read(**/*.pem)", "Edit(**/*.pem)",
      "Read(**/*.key)", "Edit(**/*.key)",
      "Read(**/*.pfx)", "Edit(**/*.pfx)",
      "Read(**/id_rsa*)", "Edit(**/id_rsa*)",
      "Read(~/.ssh/**)", "Edit(~/.ssh/**)",
      "Read(~/.aws/**)", "Edit(~/.aws/**)",
      "Read(~/.config/gh/**)", "Edit(~/.config/gh/**)",
      "Edit(**/.git/**)",
      "Bash(rm -rf:*)", "Bash(rm -fr:*)",
      "Bash(sudo:*)",
      "Bash(curl:*)", "Bash(wget:*)",
      "Bash(git push --force:*)", "Bash(git push -f:*)"
    ]
  }
}
```

### Low risk — fully autonomous (trusted personal repo)

```json
{
  "permissions": {
    "allow": [
      "Bash(bd:*)",
      "Bash(dotnet build:*)", "Bash(dotnet test:*)",
      "Bash(npm run build:*)", "Bash(npm test:*)",
      "Bash(pytest:*)", "Bash(cargo build:*)", "Bash(cargo test:*)",
      "Bash(go build:*)", "Bash(go test:*)", "Bash(make:*)",
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(git add:*)", "Bash(git commit:*)",
      "Bash(git checkout:*)", "Bash(git switch:*)",
      "Bash(git pull:*)", "Bash(git push:*)"
    ]
  }
}
```

### Medium risk — supervised (default)

```json
{
  "permissions": {
    "allow": [
      "Bash(bd:*)",
      "Bash(dotnet build:*)", "Bash(dotnet test:*)",
      "Bash(npm run build:*)", "Bash(npm test:*)",
      "Bash(pytest:*)", "Bash(cargo build:*)", "Bash(cargo test:*)",
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(git add:*)", "Bash(git checkout:*)", "Bash(git switch:*)"
    ],
    "ask": [
      "Bash(git commit:*)", "Bash(git push:*)"
    ]
  }
}
```

### High risk — locked down (untrusted/shared)

```json
{
  "permissions": {
    "allow": [
      "Bash(bd ready:*)", "Bash(bd show:*)", "Bash(bd list:*)", "Bash(bd prime)",
      "Bash(dotnet build:*)", "Bash(dotnet test:*)",
      "Bash(npm test:*)", "Bash(pytest:*)", "Bash(cargo test:*)",
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)"
    ],
    "ask": [
      "Bash(bd update:*)", "Bash(bd create:*)", "Bash(bd close:*)", "Bash(bd dep:*)",
      "Bash(git add:*)", "Bash(git commit:*)", "Bash(git push:*)"
    ]
  }
}
```

> Each tier = the safety-net `deny` **plus** the `allow`/`ask` shown; merge the two
> JSON blocks. Anything matched by no rule prompts by default, so even a partial
> `ask` list stays safe. The high tier keeps `bd` *reads* flowing (so the loop can
> still plan) while gating every `bd` *write* behind a prompt.
