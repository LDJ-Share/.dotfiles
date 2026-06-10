# dev-workflow — session bootstrap

This repo has the **dev-workflow** skills (a trimmed software-development
lifecycle). Use them.

**Instruction priority:** user instructions (CLAUDE.md / direct messages) > skills
> default behavior. Skills override defaults but always yield to the user.

**Before responding to any request, scan the available skills for a match** and
invoke the relevant one *before* acting — even before clarifying questions. If the
user explicitly opts out ("just edit it", "skip the plan"), honor that.

**Route creative work through `brainstorming`** — new features, redesigns, "let's
build X", "how should we approach Y". Don't skip to implementation. Trivial fixes,
typos, and routine commits skip the workflow.

**The lifecycle:** `brainstorming` → `writing-plans` →
(`executing-plans` | `subagent-driven-development`) → review
(`verification-before-completion`, `requesting-code-review`, `final-branch-review`)
→ `finishing-a-development-branch`. `using-git-worktrees` isolates non-trivial work;
`tiered-subagent-dispatch` + `verifying-subagent-output` govern dispatch.

Commands: `/brainstorm`, `/plan`, `/execute`, `/finish`. Full bootstrap detail is in
the `using-superpowers` skill.
