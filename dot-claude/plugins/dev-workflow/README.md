# dev-workflow

A trimmed, **language-agnostic software-development lifecycle** for constrained
(Sonnet-4.5 / 200k) workflows — the portable, slimmed-down counterpart of the full
`superpowers` plugin. Best-practice disciplines for designing, planning, executing,
reviewing, and finishing work, wired together as one chain.

## Contents

| Kind | Names |
|---|---|
| **hook** | `SessionStart` → injects a thin bootstrap (instruction-priority order, scan-skills-before-responding, route-creative-work-to-brainstorming, the lifecycle map). Fail-open. |
| **commands** | `/brainstorm` · `/plan` · `/execute` · `/finish` |
| **skills** | `using-superpowers` · `brainstorming` · `writing-plans` · `executing-plans` · `subagent-driven-development` · `tiered-subagent-dispatch` · `verifying-subagent-output` · `verification-before-completion` · `requesting-code-review` · `final-branch-review` · `iterative-review-before-commit` · `finishing-a-development-branch` · `using-git-worktrees` |

> **Always have a plan.** `/plan` writes a plan with a human in the loop; `/execute`
> won't dive into unplanned work. For *autonomous, model-approved* planning (no human
> approval pause), `/plan` and `/execute` defer to the orchestrator plugin's
> `plan-first-dispatch` skill when it's installed — the orchestrator dispatches a
> read-only `planner`, approves the plan bounded by its charter, then implements.

## The lifecycle

```
(session start: bootstrap hook → scan skills, priority order, creative→brainstorm)

brainstorming ──► writing-plans ──►  executing-plans            (inline)
   /brainstorm      /plan         │   /execute
                                  └─ subagent-driven-development (dispatch)
                                       ├─ tiered-subagent-dispatch   (model per task)
                                       └─ verifying-subagent-output  (trust the diff)
                                  │
   review gates ◄──────────────────┘
   verification-before-completion · requesting-code-review ·
   final-branch-review · iterative-review-before-commit
                                  │
                                  ▼
                    finishing-a-development-branch   (/finish)
                    (merge / PR / keep / discard)

using-git-worktrees — isolate non-trivial work throughout
```

## Pairs with — does not duplicate — the orchestrator plugin

`subagent-driven-development` and `tiered-subagent-dispatch` describe **how** to
dispatch worker subagents; the sibling **`orchestrator`** plugin supplies the actual
workers (`implementer`, `reviewer`, `scout`, `verifier`, …). Install both for the
full dispatch story; `dev-workflow` carries no agents of its own, so there's nothing
to duplicate or keep in sync.

## Relationship to the full `superpowers` plugin

These are deliberately the **same workflow, trimmed** for environments where the
full superpowers plugin isn't installed (air-gapped / Sonnet work machines). The
skill names match superpowers' on purpose. Claude Code namespaces skills by plugin
(`dev-workflow:brainstorming` vs `superpowers:brainstorming`), so the two can
coexist — but you normally install **one or the other**, not both, to avoid two
bootstraps and ambiguous bare names.

## Recommended permissions

This plugin is language-agnostic, so its permissions are the generic
development-lifecycle set: git, your build/test runner, and worktrees. The lifecycle
ends in `finishing-a-development-branch` (merge / PR / push), so the outward step to
gate is the same one every workflow has — the push. Drop one tier into the repo's
`.claude/settings.json` under `permissions`, and keep the **safety-net deny** no
matter which tier you pick. Rules evaluate **deny → ask → allow** and *deny always
wins*. When you dispatch via `subagent-driven-development`, workers inherit these
settings.

Pick a tier by trust × autonomy:

- **Low risk** — your own repo. Broad allow, almost no prompts.
- **Medium risk** *(default)* — auto-runs build/test + read-side git but **asks** before `git commit`/`push`.
- **High risk** — untrusted/shared repo; read + test only by default, **asks** on every mutation.

Trim the language runners you don't use; the examples cover the common ones.

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

### Low risk — trusted personal repo

```json
{
  "permissions": {
    "allow": [
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(git add:*)", "Bash(git commit:*)",
      "Bash(git checkout:*)", "Bash(git switch:*)", "Bash(git worktree:*)",
      "Bash(git pull:*)", "Bash(git push:*)",
      "Bash(npm:*)", "Bash(pnpm:*)", "Bash(dotnet:*)",
      "Bash(cargo:*)", "Bash(go:*)", "Bash(pytest:*)", "Bash(make:*)"
    ]
  }
}
```

### Medium risk — supervised (default)

```json
{
  "permissions": {
    "allow": [
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(git add:*)", "Bash(git checkout:*)", "Bash(git switch:*)",
      "Bash(git worktree:*)",
      "Bash(npm test:*)", "Bash(npm run build:*)",
      "Bash(dotnet build:*)", "Bash(dotnet test:*)",
      "Bash(pytest:*)", "Bash(cargo build:*)", "Bash(cargo test:*)",
      "Bash(go build:*)", "Bash(go test:*)"
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
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(dotnet build:*)", "Bash(dotnet test:*)",
      "Bash(npm test:*)", "Bash(pytest:*)", "Bash(cargo test:*)", "Bash(go test:*)"
    ],
    "ask": [
      "Bash(git add:*)", "Bash(git commit:*)", "Bash(git push:*)",
      "Bash(git worktree:*)"
    ]
  }
}
```

> Each tier = the safety-net `deny` **plus** the `allow`/`ask` shown; merge the two
> JSON blocks. Anything matched by no rule prompts by default.

## Install

Ships in the dotfiles `matt-dotfiles` marketplace
(`dot-claude/.claude-plugin/marketplace.json`). For .NET repos, also install the
sibling `dotnet-style` plugin.

## Recommended additional skills

This plugin is language-neutral, but on a **.NET** repo the `/execute` chain (and
the subagents it dispatches) does real C# coding, building, and testing. There it
performs markedly better leaning on Microsoft's official
**[dotnet-agent-skills](https://github.com/dotnet/skills)** (the *.NET Team at
Microsoft* marketplace — skills *and* dispatchable agents) than reasoning from
memory. Install the marketplace once:

```
/plugin marketplace add dotnet/skills
/plugin            # install the plugins below
```

Recommended for .NET work:

| Plugin | Reach for it when |
|---|---|
| `dotnet` | core C# mechanics during `/execute` — scripts, P/Invoke, common patterns. |
| `dotnet-test` | running/**filtering** tests, framework + platform detection, coverage and test-quality analysis. |
| `dotnet-msbuild` | a build goes red: failure diagnosis, MSBuild perf, project-file review. |

Situational: `dotnet-nuget` (packages), `dotnet-upgrade` (framework/TFM
migrations). Pair these with the `dotnet-style` plugin (formatting toolchain + stack
defaults) for full .NET coverage. On non-.NET repos, skip them.
