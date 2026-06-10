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

## Install

Ships in the dotfiles `matt-dotfiles` marketplace
(`dot-claude/.claude-plugin/marketplace.json`). For .NET repos, also install the
sibling `dotnet-style` plugin.
