# Superpowers-Lite — in-house SuperPowers shim

**Status:** Design approved 2026-04-29
**Successor:** implementation plan via `superpowers:writing-plans`
**Companion spec (separate):** `claude-hud-trim` — sibling effort, brainstormed in the same session.

## Why

The upstream SuperPowers plugin works on connected workstations through the
Claude Code marketplace, but the air-gap dev container can't reach the
marketplace and we want to avoid bundling third-party plugin code wholesale
for license-paperwork reasons. A small, in-house, vendored re-implementation
of just the skills we actually use is simpler than carrying upstream forward.

KISS and YAGNI rules from `CLAUDE.md` apply doubly here: port only what we
empirically use, reject "completeness for completeness's sake," prefer the
simplest mechanism that works.

## Scope

**In:**

- 14 user-scope Claude Code skills, vendored as markdown in this dotfiles repo
  under a new `dot-claude/` package.
- One container-only global `~/.claude/CLAUDE.md` carrying 5 universal
  discipline notes distilled from existing memory entries.
- Stow integration for the host workstation (skills only — host's existing
  `~/.claude/CLAUDE.md` is left untouched).
- Dockerfile bake for the air-gap dev container (skills + global CLAUDE.md).
- An automated test (`tests/test_superpowers_lite.sh`) verifying directory
  layout, frontmatter validity, hard-gate markers, and stow dry-run.
- A manual-verification checklist appended to this spec for the behavioral
  side that requires a live Claude Code session.

**Out of scope:**

- Versioning skills independently of the dotfiles repo. Git history is the
  version.
- Hot-reload / dev-mode skill editing on the container — rebuild the image.
- Per-project skill overrides. Skills are user-scope only; project-specific
  behavior goes in the project's CLAUDE.md.
- Co-existing with an upstream `superpowers` plugin install. Don't do that.
- A custom-agent persona. Discipline lives in skills + CLAUDE.md, not in a
  Markdown agent definition.
- A vendored justfile template for new C# projects. Copy from
  `dotnet-style-workflow` skill body when needed.

## Architecture & deployment

### Package shape

```
dot-claude/
├── .stowrc                                        # --target=~/.claude --ignore=CLAUDE\.md
├── CLAUDE.md                                      # container-only, NOT stowed
└── skills/
    ├── using-superpowers/SKILL.md
    ├── brainstorming/SKILL.md
    ├── writing-plans/SKILL.md
    ├── executing-plans/SKILL.md
    ├── subagent-driven-development/SKILL.md
    ├── using-git-worktrees/SKILL.md
    ├── verification-before-completion/SKILL.md
    ├── requesting-code-review/SKILL.md
    ├── finishing-a-development-branch/SKILL.md
    ├── tiered-subagent-dispatch/SKILL.md
    ├── final-branch-review/SKILL.md
    ├── verifying-subagent-output/SKILL.md
    ├── iterative-review-before-commit/SKILL.md
    └── dotnet-style-workflow/SKILL.md
```

Directory-per-skill layout (`<name>/SKILL.md`) is mandatory — flat `.md`
files at the same root have empirically failed to load reliably.

### Two deployment paths

1. **Host workstation** — `stow dot-claude` from the dotfiles root. `.stowrc`
   ignores `CLAUDE.md` so the existing `~/.claude/CLAUDE.md` is never
   touched. Only `~/.claude/skills/` gets populated.

2. **Air-gap dev container** — Dockerfile adds two layers near the end:
   ```dockerfile
   COPY dot-claude/skills /home/dev/.claude/skills
   COPY dot-claude/CLAUDE.md /home/dev/.claude/CLAUDE.md
   RUN chown -R dev:dev /home/dev/.claude
   ```
   No runtime fetch — air-gap clean.

### Update flow

- Host: edit a skill in dotfiles → `stow dot-claude` re-applies (idempotent).
- Container: edits picked up on next image rebuild. CI on dotfile changes
  already triggers a rebuild.

### No plugin manifest

Skills surface as `<name>` (no namespace prefix) because they're user-scope —
exactly like the existing `update-config`, `simplify`, etc. No marketplace
registration, no plugin metadata.

## The global CLAUDE.md (container-only)

Lives at `dot-claude/CLAUDE.md`, baked to `/home/dev/.claude/CLAUDE.md` in
the container. Five universal disciplines, terse-prose:

1. **No assumptions.** Verify environmental values before acting on them. If
   you can't verify, ask.
2. **No silent error swallowing.** Don't add `|| true`, `2>/dev/null`,
   conditional skips, or fallback logic that hides failure. Failures should
   be loud.
3. **LSP lies during active edits.** Trust the build, not the squiggles.
   Always verify with the project's actual build/test command before chasing
   a diagnostic.
4. **Subagents may report DONE while leaving partial state.** Especially
   haiku-tier on multi-file refactors. Verify with `git status`,
   `git show --stat <SHA>`, and a real build before trusting the report.
   See the `verifying-subagent-output` skill for the procedure.
5. **Don't auto-format after every edit.** Format at stable checkpoints, and
   keep formatter-only commits separate from behavior commits when
   practical.

The host workstation's existing `~/.claude/CLAUDE.md` already contains
related discipline (a C# csharp-ls quirk note); we don't replace or merge —
the container's version is independent.

## Skills — list with one-line behavior contracts

### Bootstrap (1)

1. **`using-superpowers`** — fires at session start; tells Claude to check
   available skills before responding and to invoke `brainstorming` before
   any creative work. Trimmed of upstream's red-flag tables and rant prose.

### Design chain (3) — hard gates between them

2. **`brainstorming`** — for creative work: one question at a time, propose
   2–3 approaches with tradeoffs, present design in approval-gated sections,
   write spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, hard
   hand-off to `writing-plans`.
3. **`writing-plans`** — turn an approved spec into a tactical implementation
   plan at `docs/superpowers/plans/YYYY-MM-DD-<topic>.md`; structure tasks
   (sequential vs parallel, dependencies); hard hand-off to `executing-plans`
   or `subagent-driven-development` depending on plan structure.
4. **`executing-plans`** — follow a written plan with task-by-task
   checkpoints; pause at review gates; emit handoffs at natural break
   points.

### Execution (1)

5. **`subagent-driven-development`** — dispatch plan tasks to subagents;
   coordinate state; review aggregated results. Soft pointer to
   `tiered-subagent-dispatch` for model selection.

### Personal-pattern skills (4)

6. **`tiered-subagent-dispatch`** — match agent model tier to task
   complexity: inline for trivial type records, haiku for mechanical
   batches, sonnet for algorithmic work, opus for review. Targets ~10k
   tokens/task.
7. **`final-branch-review`** — before declaring a branch done or merging,
   dispatch a full opus review across `master..HEAD`. Catches cross-task
   interactions per-task reviews miss. Cap output ~150 words,
   Critical/Important only.
8. **`iterative-review-before-commit`** — for security-sensitive,
   infrastructure-touching, or broad-impact changes, present diffs for user
   review BEFORE committing. Never auto-commit without explicit approval on
   sensitive paths.
9. **`verifying-subagent-output`** — after a subagent reports DONE: run
   `git status` + `git show --stat <SHA>` + grep for unfinished call sites +
   the relevant build/test before trusting. Specifically catches haiku-style
   partial edits.

### Workflow utilities (3)

10. **`using-git-worktrees`** — spin up isolated worktrees for parallel
    feature work; safety verification before destructive ops.
11. **`verification-before-completion`** — before claiming any work done
    (commit, PR, "task complete"), run actual build/test/lint commands and
    confirm output. Evidence over assertion.
12. **`requesting-code-review`** — dispatch a code-reviewer agent against a
    specific change; cap reviewer output. Distinct from `final-branch-review`
    by scope: per-change, not per-branch.

### Branch lifecycle (1)

13. **`finishing-a-development-branch`** — once impl is complete and
    verification passes, decide between direct merge / PR / cleanup;
    structured options menu.

### Language profile (1)

14. **`dotnet-style-workflow`** — fires on C#/.NET work. Preferred stack
    defaults (NUnit 4, CommunityToolkit.Mvvm, Serilog two-stage). Code
    conventions (`public sealed record` + `required init`, Nullable +
    ImplicitUsings). Format discipline (don't auto-format every edit;
    checkpoint formats; separate formatter-only commits; passive-verify
    modes; ReSharper-no-passive caveat). Standard justfile recipe shape
    (`build`, `test`, `style`, `style-verify`, `style-all`, `format-all`,
    `xaml-format-all`, `cleanup`, plus changed-files variants).

## Skill chaining

### Hard gates (3 edges)

These transitions are mandatory unless the user explicitly opts out:

```
brainstorming ──────────► writing-plans
writing-plans ──────────► executing-plans
                       └► subagent-driven-development   (when the plan structure calls for it)
```

Each design-chain skill ends with a `### Next step (required)` block that
names the exact successor and the Skill-tool invocation. The model picks
between `executing-plans` vs `subagent-driven-development` based on plan
structure (solo execution vs multi-task dispatch).

### Soft references

Each skill ends with a `### See also` block (when relevant) listing
companion skills — text-only, no Skill-tool boilerplate, no MUST language:

- `using-superpowers` → suggest `brainstorming` for creative work
- `subagent-driven-development` ↔ `tiered-subagent-dispatch`
- `subagent-driven-development` ↔ `verifying-subagent-output`
- `executing-plans` → `verification-before-completion`
- `executing-plans` → `iterative-review-before-commit`
- `executing-plans` → `requesting-code-review`
- `requesting-code-review` ↔ `final-branch-review`
- `finishing-a-development-branch` → `final-branch-review`
- `dotnet-style-workflow` — no chain edges; fires conditionally on C# work
  via its description trigger.

### User override

Hard gates yield to explicit user direction. "Skip the plan, just do it" or
"don't brainstorm, just edit" cancels the gate. Consistent with
`using-superpowers`'s priority rule: user instructions > skills > defaults.

### Cross-session behavior

Hard gates only enforce within a single conversation. A paused workflow
resumed in a new session lets the model pick up where appropriate; chain
enforcement does not carry forward. Handoff docs are the cross-session
continuity mechanism.

## Authoring methodology

### Clean-room sighted process

For each skill:

1. Extract a one-line behavior contract. For upstream-derived skills, read
   upstream once, close it mentally, write the contract in our own words.
   For personal-pattern skills, the contract comes from existing memory
   files — no upstream source involved.
2. Draft the SKILL.md from the contract, never from upstream prose. Voice
   and structure are derived from the contract, not the source.
3. Matt reviews each draft inline, edits to taste, approves.
4. Commit batches of related skills rather than one-per-commit.

### Authoring order — personal-pattern first, design-chain last

Deliberate order to minimize context-taint risk on upstream-derived skills:

| Phase | Skills | Source                                                        |
|-------|--------|---------------------------------------------------------------|
| A     | `tiered-subagent-dispatch`, `final-branch-review`, `iterative-review-before-commit`, `verifying-subagent-output` | Memory files only         |
| B     | `dotnet-style-workflow` | flight-planner CLAUDE.md + justfile                            |
| C     | `using-git-worktrees`, `verification-before-completion`, `requesting-code-review` | Light upstream            |
| D     | `subagent-driven-development`, `finishing-a-development-branch` | Upstream                                  |
| E     | `using-superpowers`, `executing-plans`, `writing-plans`, `brainstorming` | Heaviest upstream taint — written LAST |

By Phase E, our context is full of Matt's voice from earlier phases,
reducing upstream-phrasing leakage.

### Format conventions

Frontmatter (matches Claude Code's user-scope skill loader):

```yaml
---
name: <kebab-case>
description: <one short line — what the skill does + when it fires>
---
```

Length budget: terse-prose. Most skills 30–60 lines including frontmatter;
bootstrap and design-chain skills can run ~80 lines. Anything over 100 is a
design smell — split or trim.

Tone: imperative, second-person ("invoke X", "ask one question at a time").
No emojis, no all-caps stamps, no red-flag tables, no
"EXTREMELY-IMPORTANT" rants. Cross-skill references use exact skill names
in backticks.

Sections each skill includes (skip empty sections):

- One-paragraph purpose.
- The behavior contract as numbered or imperative bullets.
- `### Next step (required)` — only on the 3 design-chain skills.
- `### See also` — for soft references (most skills).
- `### When NOT to use` — for skills with high false-positive risk.

### Out of scope for authoring

- No `<HARD-GATE>` HTML-comment blocks. Plain markdown headings.
- No anti-pattern sections, "red flags" tables, or rationalization
  warnings. Trust the model.
- No version stamps in skill bodies. `git log` carries history.
- No license headers per skill. Repo's top-level LICENSE applies.

## Testing & verification

### Automated — `tests/test_superpowers_lite.sh`

New bash test in the existing pattern (alongside `test_neovim.sh`,
`test_pi.sh`). Uses `tests/container/helpers.sh` (`check_dir`, `check_file`,
`check_contains`). Coverage:

1. All 14 skill directories exist at `~/.claude/skills/<name>/` with a
   `SKILL.md` inside.
2. Each `SKILL.md` has valid frontmatter — opens with `---`, contains
   `name:` and `description:`, closes with `---`.
3. Each `SKILL.md` body is under 100 lines (soft fail / warning, not hard
   fail).
4. Hard-gate skills contain `### Next step (required)` heading
   (`brainstorming`, `writing-plans`, `executing-plans`).
5. Stow dry-run: `stow -n dot-claude` exits 0 on a clean host.
6. Container bake check: `/home/dev/.claude/skills/` exists, has 14
   directories, owned `dev:dev`. (Container-side test pass only.)

The script follows the existing `test_*.sh` shape: shebang with
`set -euo pipefail`, color helpers, `summary()`-with-exit-code at end. Wire
into whatever CI step runs the existing `test_*.sh` family.

### Manual — appended to this spec

Run once after the package lands; rerun whenever a chain skill is edited.

- **Discovery.** Start a Claude Code session in the dotfiles dir. Verify all
  14 skills appear in the available-skills list.
- **Bootstrap firing.** In a fresh session, type "let's build a new feature
  for X" — verify Claude reaches for `brainstorming` without prompting.
- **Hard-gate firing.** Complete a `brainstorming` flow through spec write —
  verify Claude transitions to `writing-plans` without being asked. Same
  check for `writing-plans` → `executing-plans` /
  `subagent-driven-development`.
- **Conditional firing.** Open a C# file, ask a code question — verify
  `dotnet-style-workflow` is offered/invoked.
- **User override.** Complete `brainstorming`, then say "skip the plan, just
  edit the file" — verify Claude honors the override and does NOT invoke
  `writing-plans`.

### Not tested

- Skill firing reliability across model versions. Anthropic-side concern.
- Performance / load time. 14 small markdown files are negligible.
- Behavior under conflicting upstream installs. Don't run both.
- Chain firing through subagent dispatch — subagents don't inherit
  user-scope skills the same way; upstream behavior, not changed here.

## Failure modes the tests catch

- Forgot to `git add` a new SKILL.md → `check_file` trips.
- Wrong directory layout (flat .md instead of `<name>/SKILL.md`) →
  `check_dir` trips.
- Frontmatter typo (`description` misspelled) → `check_contains` trips.
- Missing hard-gate marker on a design-chain skill → `check_contains`
  trips.
- Stow conflict → `stow -n` dry-run trips before any write.

## Open questions

None at design time. Implementation plan will resolve concrete details:
exact wiring of `test_superpowers_lite.sh` into the existing CI test
runner, exact Dockerfile placement of the bake step, and final SKILL.md
content for review.
