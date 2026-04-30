# superpowers-lite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author 14 vendored Claude Code skills + 1 container-only `CLAUDE.md` of universal disciplines, deploy via stow on host (skills only) and Dockerfile bake into the air-gap dev container.

**Architecture:** Skills live as markdown under `dot-claude/skills/<name>/SKILL.md`. The container-only `dot-claude/CLAUDE.md` is excluded from stow and copied directly by the Dockerfile. Author phases run from least-tainted (personal-pattern skills, no upstream source) to most-tainted (design chain, heaviest upstream prose) so the executor's voice deepens before touching the riskiest files. Hard gates only between `brainstorming → writing-plans → executing-plans/subagent-driven-development`; everything else uses soft "See also" pointers.

**Tech Stack:** Markdown (skills + CLAUDE.md), bash (test script + Dockerfile RUN), Dockerfile (multi-stage container bake), GNU Stow (host deployment).

**Spec:** `docs/superpowers/specs/2026-04-29-superpowers-lite-design.md`

**Sequencing note:** the companion `claude-hud-trim` PR (#4) introduces `dot-claude/settings.json` and pre-creates `/home/dev/.claude/` ownership in the Dockerfile. This plan ASSUMES that PR has merged before execution starts. If it hasn't merged, Tasks 14–15 below need to additionally create the directory + own it, mirroring the snippet from claude-hud-trim Task 16. Check `git log master | grep claude-hud-trim` before starting; rebase or rework Tasks 14–15 if needed.

---

## File structure

**Created:**
- `dot-claude/.stowrc` — stow targets `~/.claude` and ignores `CLAUDE.md` (container-only) and `settings.json` (already laid down by claude-hud-trim, also container-only).
- `dot-claude/CLAUDE.md` — 5 universal disciplines, container-only.
- `dot-claude/skills/using-superpowers/SKILL.md`
- `dot-claude/skills/brainstorming/SKILL.md`
- `dot-claude/skills/writing-plans/SKILL.md`
- `dot-claude/skills/executing-plans/SKILL.md`
- `dot-claude/skills/subagent-driven-development/SKILL.md`
- `dot-claude/skills/using-git-worktrees/SKILL.md`
- `dot-claude/skills/verification-before-completion/SKILL.md`
- `dot-claude/skills/requesting-code-review/SKILL.md`
- `dot-claude/skills/finishing-a-development-branch/SKILL.md`
- `dot-claude/skills/tiered-subagent-dispatch/SKILL.md`
- `dot-claude/skills/final-branch-review/SKILL.md`
- `dot-claude/skills/verifying-subagent-output/SKILL.md`
- `dot-claude/skills/iterative-review-before-commit/SKILL.md`
- `dot-claude/skills/dotnet-style-workflow/SKILL.md`
- `tests/container/test_superpowers_lite.sh` — bash deployment smoke.

**Modified:**
- `Dockerfile` — adds two COPY directives in the `final` stage: `dot-claude/skills` → `/home/dev/.claude/skills` and `dot-claude/CLAUDE.md` → `/home/dev/.claude/CLAUDE.md`. Both with `--chown=dev:dev`.
- `tests/container/run_all.sh` — appends `test_superpowers_lite.sh` to the test list.

**Untouched:** existing host `~/.claude/CLAUDE.md` (container-only deploy decision from spec); existing `dot-claude/settings.json` (laid down by claude-hud-trim PR).

---

## Authoring style — applies to every SKILL.md

Each skill must conform to these conventions (from spec Section "Authoring methodology — Format conventions"):

**Frontmatter (mandatory):**
```yaml
---
name: <kebab-case-matches-directory>
description: <one short line — what + when it fires>
---
```

**Body length budget:** 30–60 lines for utilities and personal patterns; 60–80 for bootstrap and design-chain skills. Anything over 100 = trim or split.

**Sections to include (skip empty ones):**
- One-paragraph **Purpose**.
- Numbered or imperative-bullet **behavior contract**.
- `### Next step (required)` — ONLY on the 3 design-chain skills (`brainstorming`, `writing-plans`, `executing-plans`); names the exact successor and the Skill-tool invocation.
- `### See also` — soft references to companion skills, text only, no MUST language.
- `### When NOT to use` — for skills with high false-positive risk.

**Tone:** imperative, second-person ("invoke X", "ask one question at a time"). No emojis. No all-caps stamps. No red-flag tables. No "EXTREMELY-IMPORTANT" rants. Cross-skill references use exact skill names in backticks.

**Source authoring (clean-room sighted):** for upstream-derived skills (Phases C–E), DO NOT copy text from any upstream `SKILL.md`. Read upstream once for behavior, close the file, write fresh prose from the contract bullets in this plan.

---

## Phase 1 — Stow package setup

### Task 1: Create stow package skeleton

**Files:**
- Create: `dot-claude/.stowrc`
- Create: `dot-claude/skills/.gitkeep` (placeholder so git tracks the empty directory)

- [ ] **Step 1: Create the .stowrc**

```sh
mkdir -p dot-claude/skills
```

Create `dot-claude/.stowrc`:

```
--target=~/.claude
--ignore=^CLAUDE\.md$
--ignore=^settings\.json$
```

The two `--ignore` patterns keep host stow from clashing with: (a) the existing `~/.claude/CLAUDE.md` (host has its own; ours is container-only); (b) `dot-claude/settings.json` from claude-hud-trim (also container-only).

- [ ] **Step 2: Add .gitkeep so git tracks the empty skills/ dir until skills land**

```sh
touch dot-claude/skills/.gitkeep
```

- [ ] **Step 3: Verify stow dry-run on host (informational; safe to run)**

Run: `stow -nv -d . dot-claude 2>&1 | head -10`
Expected: stow reports it would create `~/.claude/skills/` and that's it (CLAUDE.md and settings.json are ignored). No conflicts.

- [ ] **Step 4: Commit**

```bash
git add dot-claude/.stowrc dot-claude/skills/.gitkeep
git commit -m "feat(skills): set up dot-claude stow package skeleton"
```

---

## Phase 2 — Author personal-pattern skills (Phase A: zero upstream source)

These four skills derive from Matt's auto-memory only. No upstream skill source to consult. Lowest taint risk. Establish the executor's voice before tackling upstream-derived skills.

### Task 2: Author `tiered-subagent-dispatch`

**Files:**
- Create: `dot-claude/skills/tiered-subagent-dispatch/SKILL.md`

**Frontmatter:**
```yaml
---
name: tiered-subagent-dispatch
description: Match subagent model tier to task complexity — inline for trivial, haiku for mechanical batches, sonnet+opus-review for algorithmic work. Use when dispatching multi-task plans.
---
```

**Behavior contract (numbered; the SKILL.md should reflect these as imperative steps):**

1. Inspect the task's complexity before choosing a dispatch tier.
2. **Plain type records (single file, no logic)** — implement inline with the Edit/Write tool. No subagent.
3. **Mechanical work (deletes, DI wiring, csproj edits, plan-literal file edits, search-replace refactors)** — dispatch ONE haiku subagent per batch (multiple sequential tasks in a single dispatch). Skip review loops.
4. **Algorithmic work (matcher, scorer, workflow, client retry, multi-file integration)** — dispatch sonnet implementer + ONE opus combined spec+quality review (not two separate reviewers).
5. Point subagents at the plan section by file path + task number; do NOT inline full code blocks (saves 2-3k tokens per dispatch).
6. Cap reviewer output at ~150 words; Critical/Important only; skip Minor/Nit findings.
7. Always run the project's build + test suite after every implementer dispatch regardless of tier.
8. Drop per-task commentary — batch status to every 3-5 tasks or at phase boundaries.
9. Target ~10k tokens per task across implementer + reviewer combined.

**Sections:**
- Purpose paragraph: one sentence about why uniform dispatch wastes tokens.
- Numbered behavior contract.
- `### See also`: `subagent-driven-development` (the dispatcher itself), `verifying-subagent-output` (post-dispatch verification, especially for haiku).

- [ ] **Step 1: Create the directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/tiered-subagent-dispatch
```

Create `dot-claude/skills/tiered-subagent-dispatch/SKILL.md` with the frontmatter above and a body that implements the 9 contract bullets in terse imperative prose. Target 50 lines. End with the `### See also` block as specified.

- [ ] **Step 2: Verify frontmatter and length**

Run:
```sh
head -5 dot-claude/skills/tiered-subagent-dispatch/SKILL.md
wc -l dot-claude/skills/tiered-subagent-dispatch/SKILL.md
```
Expected: frontmatter shows `name:` and `description:`; line count ≤ 80.

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/tiered-subagent-dispatch/SKILL.md
git commit -m "feat(skills): add tiered-subagent-dispatch"
```

---

### Task 3: Author `final-branch-review`

**Files:**
- Create: `dot-claude/skills/final-branch-review/SKILL.md`

**Frontmatter:**
```yaml
---
name: final-branch-review
description: Before declaring a branch done or merging, dispatch an opus reviewer across master..HEAD. Catches cross-task interactions per-task reviews miss.
---
```

**Behavior contract:**

1. Before claiming a feature branch ready to merge, dispatch a single opus subagent for full-branch review.
2. Scope: `master..HEAD` (or whatever the base branch is).
3. The reviewer reads the spec, the plan, and the diff; verifies the spec was honored, looks for cross-task issues per-task reviews would miss (dead code from incremental deletes, doc drift, type inconsistencies, orphaned helpers).
4. Reviewer output capped at ~250 words; sections: Completion / CRITICAL / IMPORTANT / OBSERVATIONS. Skip Minor/Nit.
5. If CRITICAL items appear, fix them before merging — either inline or via a follow-up implementer dispatch.
6. If only OBSERVATIONS or IMPORTANT items appear, evaluate scope: fix in-branch if cheap, defer if scope-expansion.

**Sections:**
- Purpose: one-sentence justification (per-task reviews structurally miss interactions; this catches them).
- Behavior contract.
- `### When NOT to use`: trivial fixes (single-commit doc edits, single-file bug fixes) where master..HEAD = master..HEAD~1. The full-branch review is overhead-justified for multi-task feature work, not single-commit changes.
- `### See also`: `requesting-code-review` (per-change variant), `finishing-a-development-branch` (the natural caller).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/final-branch-review
```

Author `dot-claude/skills/final-branch-review/SKILL.md` per the contract. Target 40 lines.

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/final-branch-review/SKILL.md
wc -l dot-claude/skills/final-branch-review/SKILL.md
```
Expected: valid frontmatter, line count ≤ 80.

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/final-branch-review/SKILL.md
git commit -m "feat(skills): add final-branch-review"
```

---

### Task 4: Author `iterative-review-before-commit`

**Files:**
- Create: `dot-claude/skills/iterative-review-before-commit/SKILL.md`

**Frontmatter:**
```yaml
---
name: iterative-review-before-commit
description: For security-sensitive, infrastructure-touching, or broad-impact changes, present diffs for user review BEFORE running git commit. Never auto-commit those.
---
```

**Behavior contract:**

1. Detect sensitive scope before any commit: changes that touch security boundaries (auth, secrets, firewall scripts, sudoers), infrastructure (Dockerfiles, CI workflows, hooks, settings.json), or broad-impact refactors (renames affecting >5 files, deletes of top-level dirs).
2. When sensitive scope is detected, STAGE the changes but do NOT run `git commit`.
3. Present a unified diff to the user via `git diff --staged`.
4. Wait for explicit "approve" / "commit" / "looks good" before invoking `git commit`. Silence is not approval.
5. For non-sensitive changes (docs, internal refactors, single-file bug fixes), commit normally without the gate.
6. If the user requests a tweak, stash or reset the staged change, apply the tweak, re-stage, and re-present.

**Sections:**
- Purpose: one sentence noting the discipline exists because past auto-commits on security scripts caused issues.
- Behavior contract.
- `### When NOT to use`: routine docs, internal-only refactors, formatting-only commits — those would generate alert fatigue.
- `### See also`: `verification-before-completion` (similar discipline for "done" claims).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/iterative-review-before-commit
```

Author `dot-claude/skills/iterative-review-before-commit/SKILL.md` per the contract. Target 40 lines.

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/iterative-review-before-commit/SKILL.md
wc -l dot-claude/skills/iterative-review-before-commit/SKILL.md
```
Expected: valid frontmatter, line count ≤ 80.

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/iterative-review-before-commit/SKILL.md
git commit -m "feat(skills): add iterative-review-before-commit"
```

---

### Task 5: Author `verifying-subagent-output`

**Files:**
- Create: `dot-claude/skills/verifying-subagent-output/SKILL.md`

**Frontmatter:**
```yaml
---
name: verifying-subagent-output
description: After a subagent reports DONE, verify the actual git state and run the project's build/test before trusting. Specifically catches haiku-tier partial edits.
---
```

**Behavior contract:**

1. When a subagent reports DONE on a multi-file task, never accept the report at face value before verification.
2. Run `git status` to see whether anything is unstaged or untracked beyond what was claimed.
3. Run `git show --stat <SHA>` (or `git diff --stat HEAD~N..HEAD` for batch dispatches) to see the actual file footprint of the claimed work.
4. For interface changes, search the codebase for orphaned call sites: `grep -rn '<old-symbol-name>' .` should return zero hits if the change was global.
5. Run the project's build + test commands. If either fails, the work is not actually done.
6. For haiku-tier dispatches specifically: haiku subagents on multi-file refactors have been observed self-reporting success while leaving call sites unupdated. Verification is mandatory, not optional.

**Sections:**
- Purpose: one sentence noting subagents (especially haiku) can self-report success while leaving partial state.
- Behavior contract.
- `### See also`: `verification-before-completion` (related discipline; the general case), `tiered-subagent-dispatch` (defines when haiku is in play).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/verifying-subagent-output
```

Author `dot-claude/skills/verifying-subagent-output/SKILL.md` per the contract. Target 40 lines.

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/verifying-subagent-output/SKILL.md
wc -l dot-claude/skills/verifying-subagent-output/SKILL.md
```
Expected: valid frontmatter, line count ≤ 80.

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/verifying-subagent-output/SKILL.md
git commit -m "feat(skills): add verifying-subagent-output"
```

---

## Phase 3 — Author language-profile skill (Phase B: zero upstream source)

### Task 6: Author `dotnet-style-workflow`

**Files:**
- Create: `dot-claude/skills/dotnet-style-workflow/SKILL.md`

**Frontmatter:**
```yaml
---
name: dotnet-style-workflow
description: Use when working in any modern .NET project (C# 12+, dotnet 8+). Captures preferred stack defaults, code conventions, and the format-discipline workflow.
---
```

**Behavior contract:**

1. Stack defaults (use unless the project already commits to alternatives): NUnit 4 for tests, CommunityToolkit.Mvvm for ViewModels, Serilog with the two-stage bootstrap pattern (`CreateBootstrapLogger()` in entrypoint, then `UseSerilog(ReadFrom.Configuration)` on the host builder).
2. Code conventions: `public sealed record` with `required init` props for DTOs and value types. `Nullable` and `ImplicitUsings` enabled in every csproj.
3. Don't auto-format after every edit — formatting churn interrupts agent flow and can force stale file rereads. Format at stable checkpoints instead.
4. Keep formatter-only commits separate from behavior commits when practical. Reviewers can skip formatter commits at a glance.
5. For verification (CI, pre-push), prefer non-mutating "passive" modes: `dotnet format --verify-no-changes`, `xstyler --passive`, etc. ReSharper's `cleanupcode` has NO passive mode — accept that mutation is required for CleanupCode.
6. Standard justfile recipe shape (copy into a new C# project's justfile and adapt paths):
   - `client` — run the WPF/console entry project
   - `tools` — `dotnet tool restore`
   - `style` — changed-files-only style pass (CleanupCode → format → xstyler)
   - `style-verify` — non-mutating changed-files check
   - `style-all` — full-solution style pass (CleanupCode → format → xstyler)
   - `style-all-verify` — non-mutating full-solution check
   - `format-all` / `format-all-verify` — `dotnet format` solution-wide
   - `xaml-format-all` / `xaml-format-all-verify` — XamlStyler solution-wide
   - `cleanup` — CleanupCode solution-wide (no `-verify` variant — see #5)
7. LSP often shows stale NUnit / project diagnostics on test files. `dotnet test` is authoritative; don't chase LSP errors on test files unless `dotnet build` agrees.

**Sections:**
- Purpose paragraph: one sentence noting these are Matt's preferred defaults, not universal C# law.
- Behavior contract.
- `### When NOT to use`: non-.NET projects (the description filter should already exclude these); C# projects already committed to xUnit, ReactiveUI, NLog, etc. — defer to project conventions.
- `### See also`: `verification-before-completion` (general "evidence over assertion" discipline that this skill instances for .NET).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/dotnet-style-workflow
```

Author `dot-claude/skills/dotnet-style-workflow/SKILL.md` per the contract. Target 80 lines (this skill is unusually content-rich; the full justfile recipe shape needs explicit listing).

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/dotnet-style-workflow/SKILL.md
wc -l dot-claude/skills/dotnet-style-workflow/SKILL.md
```
Expected: valid frontmatter, line count ≤ 100.

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/dotnet-style-workflow/SKILL.md
git commit -m "feat(skills): add dotnet-style-workflow"
```

---

## Phase 4 — Author workflow utility skills (Phase C: light upstream taint)

These three skills have upstream equivalents. Read upstream once for behavior; close the file; write from the contract here. Don't reproduce upstream phrasing or section structure.

### Task 7: Author `using-git-worktrees`

**Files:**
- Create: `dot-claude/skills/using-git-worktrees/SKILL.md`

**Frontmatter:**
```yaml
---
name: using-git-worktrees
description: Spin up an isolated git worktree for parallel feature work. Use before starting non-trivial implementation when master needs to stay clean for parallel work.
---
```

**Behavior contract:**

1. Default worktree path: `.worktrees/<branch-name>/` at the repo root (the dotfiles convention; see CONVENTIONS.md if unsure).
2. Create the worktree: `git worktree add .worktrees/<branch-name> -b <branch-name>`.
3. Verify the path doesn't already exist before adding. If it does, ask the user whether to reuse or pick a different name.
4. After creation, `cd` into the worktree for subsequent operations.
5. Never delete a worktree without explicit user confirmation. Use `git worktree remove <path>` (not `rm -rf`) so git's worktree registry stays consistent.
6. When work is complete and merged, prefer `git worktree remove` over leaving stale worktrees on disk.
7. Don't create nested worktrees (worktree inside another worktree) — that's a foot-gun.

**Sections:**
- Purpose: one sentence about isolation from current workspace state.
- Behavior contract.
- `### When NOT to use`: tiny one-shot fixes that take less than 10 minutes — branch in the main checkout instead, less ceremony.
- `### See also`: `finishing-a-development-branch` (handles worktree cleanup at branch completion).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/using-git-worktrees
```

Author `dot-claude/skills/using-git-worktrees/SKILL.md` per the contract. Target 40 lines.

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/using-git-worktrees/SKILL.md
wc -l dot-claude/skills/using-git-worktrees/SKILL.md
```
Expected: valid frontmatter, line count ≤ 80.

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/using-git-worktrees/SKILL.md
git commit -m "feat(skills): add using-git-worktrees"
```

---

### Task 8: Author `verification-before-completion`

**Files:**
- Create: `dot-claude/skills/verification-before-completion/SKILL.md`

**Frontmatter:**
```yaml
---
name: verification-before-completion
description: Before claiming any work is complete (commit, PR, "task done"), run the project's actual build/test/lint commands and confirm output. Evidence over assertion.
---
```

**Behavior contract:**

1. Before declaring any non-trivial task done, run the project's actual verification commands. This means whatever the project conventionally uses: `go test ./...`, `dotnet test`, `npm test`, `pytest`, `cargo test`, etc.
2. Also run the project's build (`go build`, `dotnet build`, `npm run build`) — passing tests don't catch type errors that the runtime never reaches.
3. Show evidence in the report: exit code, summary line ("9/9 PASS"), or relevant output snippet. Do not claim "tests pass" without showing it.
4. If verification reveals problems, do not paper over them or downgrade the claim ("works locally") — fix or surface.
5. For multi-language projects, run all relevant verifications (e.g., a project with both Go and C# components needs both `go test` and `dotnet test`).

**Sections:**
- Purpose: one sentence — model self-reports without verification are unreliable.
- Behavior contract.
- `### See also`: `verifying-subagent-output` (related discipline applied to subagent reports specifically).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/verification-before-completion
```

Author `dot-claude/skills/verification-before-completion/SKILL.md` per the contract. Target 30 lines.

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/verification-before-completion/SKILL.md
wc -l dot-claude/skills/verification-before-completion/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/verification-before-completion/SKILL.md
git commit -m "feat(skills): add verification-before-completion"
```

---

### Task 9: Author `requesting-code-review`

**Files:**
- Create: `dot-claude/skills/requesting-code-review/SKILL.md`

**Frontmatter:**
```yaml
---
name: requesting-code-review
description: Dispatch a reviewer subagent for a specific change. Use after implementing a non-trivial commit or before merging when the change warrants targeted review.
---
```

**Behavior contract:**

1. Use the Agent tool with model selection appropriate to the change: sonnet for routine review, opus for high-blast-radius changes (security, infrastructure, broad-impact refactors).
2. Scope the review to the specific change under consideration (a single commit, a single file, a feature increment) — not the whole codebase.
3. Provide the reviewer with: the spec or task description, the relevant commit SHA(s), the file paths under review.
4. Cap reviewer output at ~150 words. Critical/Important findings only; skip Minor and Nit.
5. After review, fix Critical and Important findings before moving on. Defer or document Minor findings.
6. Don't dispatch the reviewer in parallel with other reviewers on overlapping files — they can produce contradictory advice.

**Sections:**
- Purpose: per-change review at task or commit boundaries (distinct from `final-branch-review` which scans `master..HEAD`).
- Behavior contract.
- `### When NOT to use`: trivial commits (typo fixes, single-line tweaks) where review overhead exceeds the change.
- `### See also`: `final-branch-review` (whole-branch variant; usually fires later in the lifecycle).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/requesting-code-review
```

Author `dot-claude/skills/requesting-code-review/SKILL.md` per the contract. Target 40 lines.

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/requesting-code-review/SKILL.md
wc -l dot-claude/skills/requesting-code-review/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/requesting-code-review/SKILL.md
git commit -m "feat(skills): add requesting-code-review"
```

---

## Phase 5 — Author execution + lifecycle skills (Phase D)

### Task 10: Author `subagent-driven-development`

**Files:**
- Create: `dot-claude/skills/subagent-driven-development/SKILL.md`

**Frontmatter:**
```yaml
---
name: subagent-driven-development
description: Execute a written plan by dispatching fresh subagents per task (or per batch, per the tiered-subagent-dispatch policy). Coordinate state in the controller; preserve subagent context isolation.
---
```

**Behavior contract:**

1. Read the plan once. Extract every task's full text and supporting context up front.
2. Create a TodoWrite list mirroring the plan's tasks. Update statuses as work progresses.
3. For each task (or batch, per `tiered-subagent-dispatch`):
   a. Dispatch the implementer subagent with full task text inline (don't make the subagent re-read the plan file — wastes tokens).
   b. If the subagent reports NEEDS_CONTEXT, answer questions and re-dispatch.
   c. If it reports BLOCKED, assess: provide more context, dispatch a more capable model, break the task smaller, or escalate to the user.
   d. If it reports DONE_WITH_CONCERNS, read the concerns; address correctness/scope concerns before review.
   e. If it reports DONE, run verification per `verifying-subagent-output`.
4. Per tier: mechanical work batches under one haiku dispatch with NO review loop. Algorithmic work uses sonnet implementer + ONE opus combined spec+quality review.
5. Never dispatch multiple implementer subagents in parallel on overlapping files — race conditions.
6. After all tasks complete, dispatch `final-branch-review` before declaring the branch done.

**Sections:**
- Purpose: one sentence — subagent isolation preserves controller context.
- Behavior contract.
- `### See also`: `tiered-subagent-dispatch` (defines model selection), `verifying-subagent-output` (post-dispatch verification), `final-branch-review` (branch-end gate), `requesting-code-review` (per-change review pattern).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/subagent-driven-development
```

Author `dot-claude/skills/subagent-driven-development/SKILL.md` per the contract. Target 60 lines.

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/subagent-driven-development/SKILL.md
wc -l dot-claude/skills/subagent-driven-development/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/subagent-driven-development/SKILL.md
git commit -m "feat(skills): add subagent-driven-development"
```

---

### Task 11: Author `finishing-a-development-branch`

**Files:**
- Create: `dot-claude/skills/finishing-a-development-branch/SKILL.md`

**Frontmatter:**
```yaml
---
name: finishing-a-development-branch
description: At branch completion, choose between merge / PR / keep-as-is / discard. Verify tests first, present 4 options, execute the chosen path, clean up worktree if applicable.
---
```

**Behavior contract:**

1. Before presenting options, verify the project's tests pass. If they fail, stop and surface the failures — don't proceed to options until they're fixed.
2. Determine the base branch via `git merge-base HEAD master 2>/dev/null` (or `main`). Confirm with the user if ambiguous.
3. Present exactly 4 options (no extra explanation):
   - Merge back to base locally.
   - Push and create a Pull Request.
   - Keep the branch as-is.
   - Discard this work.
4. For "Discard": require typed confirmation ("type 'discard' to confirm"). Don't accept "yes" or "ok".
5. Execute the chosen path:
   - **Merge locally**: checkout base, pull, merge, run tests on merged result, delete the feature branch.
   - **Push + PR**: `git push -u origin <branch>` then `gh pr create --base <base> --head <branch> --title ... --body ...`. PR body should include a Summary section and a Test plan section with checkbox items.
   - **Keep as-is**: report the branch name and worktree path.
   - **Discard**: checkout base, force-delete the branch (`git branch -D`).
6. Worktree cleanup: only for Merge and Discard. For PR and Keep-as-is, leave the worktree intact.

**Sections:**
- Purpose: one sentence on the branch-completion decision point.
- Behavior contract.
- `### See also`: `final-branch-review` (run BEFORE this skill, not as part of it), `using-git-worktrees` (for cleanup on Merge/Discard paths).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/finishing-a-development-branch
```

Author `dot-claude/skills/finishing-a-development-branch/SKILL.md` per the contract. Target 60 lines.

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/finishing-a-development-branch/SKILL.md
wc -l dot-claude/skills/finishing-a-development-branch/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/finishing-a-development-branch/SKILL.md
git commit -m "feat(skills): add finishing-a-development-branch"
```

---

## Phase 6 — Author bootstrap + design chain (Phase E: heaviest taint)

These four skills have the most upstream prose. By now the executor has authored 9 skills in Matt's voice — context taint should be minimal. Still: read upstream only for behavior verification, write fresh from the contract here.

### Task 12: Author `using-superpowers` (bootstrap)

**Files:**
- Create: `dot-claude/skills/using-superpowers/SKILL.md`

**Frontmatter:**
```yaml
---
name: using-superpowers
description: Session-start bootstrap. Tells Claude to check available skills before responding and to invoke brainstorming for any creative work.
---
```

**Behavior contract:**

1. This skill fires at session start (typically via the Claude Code SessionStart hook).
2. Establish instruction priority: user instructions (CLAUDE.md, GEMINI.md, AGENTS.md, direct messages) > skills > default behavior. Skills override defaults but yield to user direction.
3. Before responding to any user message, scan the available-skills list for matches. If a skill applies — even probably-applies — invoke it via the Skill tool BEFORE responding.
4. Specifically: any creative work (new features, designs, redesigns, brainstorms) requires `brainstorming` first. "Let's build X", "design a Y", "how should we approach Z" — these are brainstorming triggers.
5. Use TodoWrite to track multi-step plans surfaced during brainstorming/writing-plans.
6. When user explicitly opts out of a skill's discipline ("just edit the file", "skip the plan"), honor that — it's user instruction outranking skill defaults.

**Sections:**
- Purpose: one sentence — entry skill that establishes priorities.
- Behavior contract.
- `### See also`: `brainstorming` (the most common downstream invocation), `writing-plans` and `executing-plans` (downstream of brainstorming).
- NO `### Next step (required)` section — this skill doesn't hard-gate; it advises.

**Length budget exception:** this skill is allowed up to 80 lines because the priority rules and trigger detection require explicit prose.

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/using-superpowers
```

Author `dot-claude/skills/using-superpowers/SKILL.md` per the contract. Target 70 lines.

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/using-superpowers/SKILL.md
wc -l dot-claude/skills/using-superpowers/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/using-superpowers/SKILL.md
git commit -m "feat(skills): add using-superpowers bootstrap"
```

---

### Task 13: Author `executing-plans` (design chain — terminal)

**Files:**
- Create: `dot-claude/skills/executing-plans/SKILL.md`

**Frontmatter:**
```yaml
---
name: executing-plans
description: Follow a written implementation plan task-by-task with checkpoints. Run tests at each gate; commit per task; pause for review at natural breakpoints.
---
```

**Behavior contract:**

1. Receive a plan path (either via skill argument or from a `writing-plans` hand-off).
2. Read the plan once. Identify the task list and any phase boundaries.
3. Execute tasks sequentially. For each:
   a. Read the task's steps and expected outputs.
   b. Implement.
   c. Run any verification commands the task specifies.
   d. Commit with the task's prescribed message.
   e. Update task tracker (TodoWrite or equivalent).
4. At natural checkpoints (end of phase, after a gnarly multi-file task, before destructive operations) pause and surface progress to the user.
5. If you discover the plan is wrong (a task's instructions don't fit reality), stop and surface — don't improvise around the plan silently.
6. At the end of the plan, hand off to `finishing-a-development-branch` for the merge/PR decision (don't merge unilaterally).
7. If the work is incomplete at session end, write a handoff doc at `docs/superpowers/handoff/YYYY-MM-DD-<topic>-next-session.md` summarizing state.

**Sections:**
- Purpose: one sentence on inline execution vs subagent dispatch.
- Behavior contract.
- This is the TERMINAL design-chain skill — there is no `### Next step (required)`.
- `### See also`: `subagent-driven-development` (the alternative — dispatch tasks to subagents instead of executing inline), `verification-before-completion` (per-task verification), `iterative-review-before-commit` (for sensitive commits during execution), `requesting-code-review` (mid-execution review at non-trivial task completion), `finishing-a-development-branch` (handles end-of-plan).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/executing-plans
```

Author `dot-claude/skills/executing-plans/SKILL.md` per the contract. Target 60 lines.

- [ ] **Step 2: Verify**

Run:
```sh
head -5 dot-claude/skills/executing-plans/SKILL.md
wc -l dot-claude/skills/executing-plans/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add dot-claude/skills/executing-plans/SKILL.md
git commit -m "feat(skills): add executing-plans"
```

---

### Task 14: Author `writing-plans` (design chain — middle)

**Files:**
- Create: `dot-claude/skills/writing-plans/SKILL.md`

**Frontmatter:**
```yaml
---
name: writing-plans
description: Convert an approved spec into a tactical implementation plan with bite-sized tasks. Save to docs/superpowers/plans/YYYY-MM-DD-<topic>.md.
---
```

**Behavior contract:**

1. Read the spec at the path provided (typically from a `brainstorming` hand-off).
2. Map out the file structure: which files will be created or modified, what each is responsible for. Lock in decomposition decisions before defining tasks.
3. Define tasks. Each task is a logical unit of work (typically 15–30 minutes) broken into 2–5 minute steps.
4. Each step shows EXACT content: file paths, full code blocks, exact commands, expected output. No "TBD" / "implement later" / "add appropriate error handling" / "similar to Task N" — these are plan failures.
5. Tasks for new behavior follow TDD: write failing test → run to confirm fail → minimal impl → run to confirm pass → commit.
6. Tasks for deletions follow regression-test-first: write tests against current behavior → confirm pass → delete → confirm tests still pass → commit.
7. Save the plan to `docs/superpowers/plans/YYYY-MM-DD-<topic>.md` (use today's date).
8. Self-review the plan: does every spec section have a task? Any placeholders? Type/signature consistency across tasks?
9. Hard hand-off: at the end of the plan, state explicitly that the next step is `executing-plans` OR `subagent-driven-development` (depending on whether the plan has parallel-safe tasks).

**Required sections in this SKILL.md:**
- Purpose, behavior contract, `### See also`, AND a `### Next step (required)` block specifying that completion of THIS skill (writing-plans) hands off to either `executing-plans` (sequential inline execution) or `subagent-driven-development` (subagent dispatch) based on plan structure.

**`### See also`:** `brainstorming` (the upstream feeder), `executing-plans` (one of two downstream options), `subagent-driven-development` (the other).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/writing-plans
```

Author `dot-claude/skills/writing-plans/SKILL.md` per the contract. Target 70 lines.

- [ ] **Step 2: Verify the hard-gate marker is present**

Run: `grep -c '### Next step (required)' dot-claude/skills/writing-plans/SKILL.md`
Expected: 1 (exactly one occurrence — the hard-gate block).

- [ ] **Step 3: Verify general**

Run:
```sh
head -5 dot-claude/skills/writing-plans/SKILL.md
wc -l dot-claude/skills/writing-plans/SKILL.md
```

- [ ] **Step 4: Commit**

```bash
git add dot-claude/skills/writing-plans/SKILL.md
git commit -m "feat(skills): add writing-plans"
```

---

### Task 15: Author `brainstorming` (design chain — head)

**Files:**
- Create: `dot-claude/skills/brainstorming/SKILL.md`

**Frontmatter:**
```yaml
---
name: brainstorming
description: For creative work (new features, designs, redesigns). Explore intent through one-question-at-a-time dialogue; produce a spec doc for downstream planning.
---
```

**Behavior contract:**

1. Before any creative-work substantive output, run this skill. "Creative work" means: new features, redesigns, "let's build X", "how should we approach Y".
2. Explore project context first: relevant files, recent commits, related docs.
3. Ask clarifying questions ONE AT A TIME. Multiple choice when possible (lower cognitive cost than open-ended).
4. After enough context, propose 2–3 approaches with tradeoffs. Recommend one explicitly with reasoning.
5. Present the design in approval-gated sections (architecture, components, behaviors, etc.). Get explicit approval per section before moving on.
6. Decompose if scope is too large for a single spec: surface the decomposition before going deep on any sub-project.
7. Save the spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
8. Self-review the written spec: any placeholders, contradictions, scope-creep, ambiguity? Fix inline.
9. Ask the user to review the written spec before transitioning.
10. Hard hand-off: invoke `writing-plans` for the implementation plan.

**Required sections:**
- Purpose, behavior contract, `### When NOT to use`, AND a `### Next step (required)` block invoking `writing-plans` after spec approval.

**`### When NOT to use`:** trivial fixes (single-line bug, typo), routine commits, debug investigations — those don't need brainstorming overhead.

**`### See also`:** `writing-plans` (the mandatory next step), `using-superpowers` (the bootstrap that triggers this skill for creative work).

- [ ] **Step 1: Create directory and SKILL.md**

```sh
mkdir -p dot-claude/skills/brainstorming
```

Author `dot-claude/skills/brainstorming/SKILL.md` per the contract. Target 80 lines.

- [ ] **Step 2: Verify the hard-gate marker is present**

Run: `grep -c '### Next step (required)' dot-claude/skills/brainstorming/SKILL.md`
Expected: 1.

- [ ] **Step 3: Verify general**

Run:
```sh
head -5 dot-claude/skills/brainstorming/SKILL.md
wc -l dot-claude/skills/brainstorming/SKILL.md
```

- [ ] **Step 4: Commit**

```bash
git add dot-claude/skills/brainstorming/SKILL.md
git commit -m "feat(skills): add brainstorming"
```

---

## Phase 7 — Container-only global CLAUDE.md

### Task 16: Author `dot-claude/CLAUDE.md`

**Files:**
- Create: `dot-claude/CLAUDE.md`

This file gets baked into the air-gap dev container at `/home/dev/.claude/CLAUDE.md` via the Dockerfile (Task 19). It's NOT stowed to the host (the `.stowrc --ignore=^CLAUDE\.md$` rule from Task 1 keeps the host's existing `~/.claude/CLAUDE.md` untouched).

**Content:** five universal disciplines distilled from Matt's auto-memory. Terse-prose; same style as the rest of the dotfiles `CLAUDE.md`.

- [ ] **Step 1: Create the file**

Create `dot-claude/CLAUDE.md`:

```markdown
# Universal disciplines

These apply to every session in this dev container. Project-specific
preferences belong in the project's own `CLAUDE.md`.

## No assumptions

Never make changes based on assumed or "typical" environmental values
(UIDs, ports, paths, version numbers). Verify by reading the file or
running the command first. If you can't verify autonomously, ask the
user — don't guess.

## No silent error swallowing

Don't add `|| true`, `2>/dev/null`, conditional skips, or fallback logic
that hides failure. Failures should be loud. We learn from failures; we
don't ignore them.

## LSP lies during active edits

LSP diagnostics are unreliable immediately after writes — especially in
.NET projects via csharp-ls. Trust the build, not the squiggles. Always
verify with the project's actual build command (`dotnet build`,
`go build`, `cargo check`, etc.) before chasing a diagnostic.

## Subagents may report DONE while leaving partial state

Especially haiku-tier subagents on multi-file refactors. After any
subagent reports DONE: run `git status`, `git show --stat <SHA>`, and
the project's build/test before trusting. See the
`verifying-subagent-output` skill for the procedure.

## Don't auto-format after every edit

Format at stable checkpoints, and keep formatter-only commits separate
from behavior commits when practical. Constant formatting churn forces
stale file rereads and disrupts agent flow.
```

- [ ] **Step 2: Verify**

Run:
```sh
wc -l dot-claude/CLAUDE.md
head -3 dot-claude/CLAUDE.md
```
Expected: ~30 lines, starts with the H1 heading.

- [ ] **Step 3: Commit**

```bash
git add dot-claude/CLAUDE.md
git commit -m "feat(skills): add container-only universal-disciplines CLAUDE.md"
```

---

## Phase 8 — Bash deployment smoke

### Task 17: Author `tests/container/test_superpowers_lite.sh`

**Files:**
- Create: `tests/container/test_superpowers_lite.sh`

- [ ] **Step 1: Create the test script**

Create `tests/container/test_superpowers_lite.sh`:

```bash
#!/usr/bin/env bash
# test_superpowers_lite.sh — verify the vendored Claude Code skills are
# present and well-formed in the container.
set -uo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

SKILLS_DIR="${HOME}/.claude/skills"
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"

EXPECTED_SKILLS=(
  using-superpowers
  brainstorming
  writing-plans
  executing-plans
  subagent-driven-development
  using-git-worktrees
  verification-before-completion
  requesting-code-review
  finishing-a-development-branch
  tiered-subagent-dispatch
  final-branch-review
  verifying-subagent-output
  iterative-review-before-commit
  dotnet-style-workflow
)

HARD_GATE_SKILLS=(
  brainstorming
  writing-plans
  executing-plans
)

echo "=== superpowers-lite: skill directories exist ==="

check_dir "${SKILLS_DIR}"

for s in "${EXPECTED_SKILLS[@]}"; do
  check_dir "${SKILLS_DIR}/${s}"
  check_file "${SKILLS_DIR}/${s}/SKILL.md"
done

echo "=== superpowers-lite: SKILL.md frontmatter ==="

for s in "${EXPECTED_SKILLS[@]}"; do
  f="${SKILLS_DIR}/${s}/SKILL.md"
  if [[ ! -f "$f" ]]; then
    continue
  fi
  check "$s frontmatter opens with ---" bash -c "head -1 '$f' | grep -q '^---$'"
  check_contains "$s has name field" "$f" "^name:"
  check_contains "$s has description field" "$f" "^description:"
done

echo "=== superpowers-lite: design-chain hard-gate markers ==="

for s in "${HARD_GATE_SKILLS[@]}"; do
  f="${SKILLS_DIR}/${s}/SKILL.md"
  check_contains "$s has hard-gate marker" "$f" "Next step (required)"
done

echo "=== superpowers-lite: SKILL.md length budget ==="

for s in "${EXPECTED_SKILLS[@]}"; do
  f="${SKILLS_DIR}/${s}/SKILL.md"
  if [[ ! -f "$f" ]]; then
    continue
  fi
  lines=$(wc -l < "$f")
  if [[ "$lines" -le 100 ]]; then
    echo "  PASS: $s SKILL.md is $lines lines (≤100)"
    ((PASS++)) || true
  else
    echo "  WARN: $s SKILL.md is $lines lines (>100 — soft fail; investigate)"
    # Soft fail: warn but don't increment FAIL.
  fi
done

echo "=== superpowers-lite: container-only CLAUDE.md ==="

check_file "${CLAUDE_MD}"
check_contains "CLAUDE.md mentions universal disciplines" "${CLAUDE_MD}" "Universal disciplines"

echo "=== superpowers-lite: stow dry-run ==="

if [[ -d "${HOME}/.dotfiles/dot-claude" ]]; then
  if stow -nv -d "${HOME}/.dotfiles" -t "${HOME}/.claude" dot-claude >/dev/null 2>&1; then
    echo "  PASS: stow dry-run clean"
    ((PASS++)) || true
  else
    echo "  FAIL: stow dry-run reports conflicts"
    ((FAIL++)) || true
  fi
else
  echo "  SKIP: dotfiles not stowed at ~/.dotfiles (container-side test)"
fi

summary
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x tests/container/test_superpowers_lite.sh
```

- [ ] **Step 3: Parse-check**

Run: `bash -n tests/container/test_superpowers_lite.sh && echo ok`
Expected: `ok`.

- [ ] **Step 4: Commit**

```bash
git add tests/container/test_superpowers_lite.sh
git commit -m "test(skills): add bash deployment smoke for superpowers-lite"
```

---

### Task 18: Wire `test_superpowers_lite.sh` into `run_all.sh`

**Files:**
- Modify: `tests/container/run_all.sh`

- [ ] **Step 1: Read current state**

Run: `cat tests/container/run_all.sh`
Expected: a `TESTS=( ... )` array (per claude-hud-trim Plan Task 18 observation).

- [ ] **Step 2: Add `test_superpowers_lite.sh` to the TESTS array**

The exact insertion line depends on `run_all.sh`'s current array contents — append `test_superpowers_lite.sh` to the array, matching whatever indentation/quoting the existing entries use.

- [ ] **Step 3: Parse-check**

Run: `bash -n tests/container/run_all.sh && echo ok`
Expected: `ok`.

- [ ] **Step 4: Commit**

```bash
git add tests/container/run_all.sh
git commit -m "test(skills): wire superpowers-lite test into run_all.sh"
```

---

## Phase 9 — Container bake

### Task 19: Add Dockerfile COPY layers

**Files:**
- Modify: `Dockerfile` (the `final` stage, near where `dot-claude/settings.json` is copied — that's around line 341 after claude-hud-trim merges).

- [ ] **Step 1: Read the relevant section**

Run: `grep -n -A2 -B2 'dot-claude/settings.json\|claude-hud' Dockerfile | head -30`
Expected: shows the existing `RUN install -d -o dev -g dev /home/dev/.claude` line plus the `COPY --chown=dev:dev dot-claude/settings.json` line.

- [ ] **Step 2: Add two COPY directives in the final stage**

After the existing `COPY --chown=dev:dev dot-claude/settings.json /home/dev/.claude/settings.json` line, add:

```dockerfile
# ── Vendored Claude Code skills (superpowers-lite)
COPY --chown=dev:dev dot-claude/skills /home/dev/.claude/skills

# ── Container-only universal-disciplines CLAUDE.md
COPY --chown=dev:dev dot-claude/CLAUDE.md /home/dev/.claude/CLAUDE.md
```

The pre-existing `RUN install -d -o dev -g dev /home/dev/.claude` (laid down by claude-hud-trim) handles parent-dir ownership. The two new COPYs use `--chown=dev:dev` so the skill files and CLAUDE.md land owned by `dev`.

If claude-hud-trim has NOT merged yet (the sequencing note at the top of this plan), prepend an `RUN install -d -o dev -g dev /home/dev/.claude` line BEFORE the COPYs to handle parent-dir ownership.

- [ ] **Step 3: Sanity-check the Dockerfile**

Run: `grep -n 'dot-claude' Dockerfile`
Expected: shows three (or four, if you added the install -d line) lines: the settings.json COPY, the skills COPY, and the CLAUDE.md COPY.

- [ ] **Step 4: Commit**

```bash
git add Dockerfile
git commit -m "feat(container): bake vendored skills and universal CLAUDE.md"
```

---

## Phase 10 — Manual verification

### Task 20: Manual verification (Matt runs this)

**Files:** none (run-through against a built image and a stowed host).

This is a manual gate. Mark complete only when each item is verified.

- [ ] **Step 1: Stow on host**

```sh
cd ~/.dotfiles
stow dot-claude
ls -la ~/.claude/skills/ | head
```
Expected: 14 directories under `~/.claude/skills/`. The host's existing `~/.claude/CLAUDE.md` is untouched (the `.stowrc` ignore did its job).

- [ ] **Step 2: Discovery — list available skills in a fresh session**

Start a new Claude Code session. Verify the available-skills list at session start includes all 14 skill names.

- [ ] **Step 3: Bootstrap firing**

In a fresh session, type "let's build a new feature for X". Verify Claude reaches for `brainstorming` without prompting.

- [ ] **Step 4: Hard-gate firing**

Complete a `brainstorming` flow through to spec write. Verify Claude transitions to `writing-plans` without being asked. Same check for `writing-plans` → `executing-plans` / `subagent-driven-development`.

- [ ] **Step 5: Conditional firing**

Open a C# file (any project), ask a code question. Verify `dotnet-style-workflow` is offered or invoked.

- [ ] **Step 6: User override**

Complete `brainstorming`, then say "skip the plan, just edit the file". Verify Claude honors the override and does NOT invoke `writing-plans`.

- [ ] **Step 7: Container check (after image rebuild)**

Build the dev-env image. Inside the container:

```sh
ls /home/dev/.claude/skills/ | wc -l       # expect 14
ls -la /home/dev/.claude/CLAUDE.md          # owned by dev:dev
bash /home/dev/.dotfiles/tests/container/test_superpowers_lite.sh
```

Expected: 14 skill directories; CLAUDE.md present and dev-owned; bash test reports all PASS.

If everything passes, the plan is done. Otherwise, surface specific failures and dispatch a fix subagent.

---

## Self-review

**Spec coverage:**
- ✓ Architecture & deployment (skills via stow, CLAUDE.md container-only) → Tasks 1, 16, 19.
- ✓ All 14 skill names → Tasks 2–15 (one task per skill, mapped 1:1).
- ✓ Personal-pattern skills first (Phase A) → Tasks 2–5.
- ✓ Language profile (Phase B) → Task 6.
- ✓ Workflow utilities (Phase C) → Tasks 7–9.
- ✓ Execution + lifecycle (Phase D) → Tasks 10–11.
- ✓ Bootstrap + design chain (Phase E, last) → Tasks 12–15.
- ✓ Hard gates only on design chain → enforced via the `### Next step (required)` requirement in Tasks 14, 15 (and the verification `grep` check).
- ✓ Soft references via `### See also` → specified per skill.
- ✓ Universal disciplines CLAUDE.md (5 items) → Task 16.
- ✓ Bash test with 6 check categories → Task 17.
- ✓ Wired into run_all.sh → Task 18.
- ✓ Dockerfile bake → Task 19.
- ✓ Manual verification (5 smoke checks from spec) → Task 20.

**Placeholder scan:** None. Each skill task names the exact frontmatter, contract bullets, sections to include, and length budget. The behavior-contract bullets are detailed enough for clean-room sighted authoring.

**Type / signature consistency:** N/A for markdown skills. Verified consistency in skill-name references across `### See also` blocks (e.g., `tiered-subagent-dispatch` is named consistently; `subagent-driven-development` is named consistently).

**Sequencing hazard documented:** the dependency on claude-hud-trim's `dot-claude/settings.json` and `RUN install -d` line is flagged at the top and again in Task 19's Step 2.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-30-superpowers-lite.md`. Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task; review between tasks per Matt's tiered dispatch (most skill-authoring tasks are sonnet-tier; the test-script and Dockerfile tasks are sonnet+opus-review).

**2. Inline Execution** — execute tasks in this session using `executing-plans`; batch execution with checkpoints for review.

Which approach?
