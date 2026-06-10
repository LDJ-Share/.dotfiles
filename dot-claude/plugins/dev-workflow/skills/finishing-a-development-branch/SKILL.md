---
name: finishing-a-development-branch
description: At branch completion, choose between merge / PR / keep-as-is / discard. Verify tests first, present 4 options, execute the chosen path, clean up worktree if applicable.
---

## Purpose

The branch-completion decision point. Verify the branch is healthy, then ask the user what to do with it — merge, PR, keep, or discard — and execute that one cleanly.

## Behavior

1. Before presenting options, verify the project's tests pass. If they fail, stop and surface the failures. Don't proceed to options until they're fixed.
2. Determine the base branch via `git merge-base HEAD master 2>/dev/null` (or `main`). Confirm with the user if ambiguous.
3. Present exactly four options, no extra explanation:
   - Merge back to base locally.
   - Push and create a Pull Request.
   - Keep the branch as-is.
   - Discard this work.
4. For "Discard": require typed confirmation — "type 'discard' to confirm". Don't accept "yes" or "ok" as confirmation for destructive paths.
5. Execute the chosen path:
   - **Merge locally** — checkout base, pull, merge, run tests on the merged result, delete the feature branch.
   - **Push + PR** — `git push -u origin <branch>` then `gh pr create --base <base> --head <branch>` with a Summary section and a Test plan checklist in the body.
   - **Keep as-is** — report the branch name and worktree path.
   - **Discard** — checkout base, force-delete the branch (`git branch -D`).
6. Worktree cleanup: only on Merge and Discard paths. On PR and Keep-as-is, leave the worktree intact.

### See also

- `final-branch-review` — run BEFORE this skill, not as part of it.
- `using-git-worktrees` — for cleanup on Merge and Discard paths.
