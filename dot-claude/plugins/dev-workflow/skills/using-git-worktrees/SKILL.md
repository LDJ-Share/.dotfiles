---
name: using-git-worktrees
description: Spin up an isolated git worktree for parallel feature work. Use before starting non-trivial implementation when master needs to stay clean for parallel work.
---

## Purpose

Worktrees give a feature branch its own working directory so the main checkout stays clean and parallel work doesn't share an index. Use when a non-trivial implementation needs isolation from current workspace state.

## Behavior

1. Default worktree path: `.worktrees/<branch-name>/` at the repo root. (Dotfiles convention; see CONVENTIONS.md if unsure.)
2. Create the worktree with `git worktree add .worktrees/<branch-name> -b <branch-name>`.
3. Verify the path doesn't already exist before adding. If it does, ask the user whether to reuse or pick a different name.
4. After creation, `cd` into the worktree for subsequent operations. Don't operate on the main checkout's index by accident.
5. Never delete a worktree without explicit user confirmation. Use `git worktree remove <path>` — not `rm -rf` — so git's worktree registry stays consistent.
6. When work is complete and merged, prefer `git worktree remove` over leaving stale worktrees on disk.
7. Don't create nested worktrees (a worktree inside another worktree). It's a foot-gun and the registry behaviour is undefined in places.

### When NOT to use

Tiny one-shot fixes that take less than 10 minutes. Branch in the main checkout instead — the worktree ceremony costs more than it saves.

### See also

- `finishing-a-development-branch` — handles worktree cleanup at branch completion.
