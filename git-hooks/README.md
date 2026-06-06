# Shared git hooks — stay off master

Belt-and-suspenders guards that keep direct work off `master`/`main`. The Brain
workflow is PR-based: branch → commit → push branch → PR → merge. These hooks
enforce that for both humans and agents.

| Hook | Blocks |
|------|--------|
| `pre-commit` | committing while `HEAD` is on `master`/`main` |
| `pre-push`   | pushing a ref to `refs/heads/master` or `refs/heads/main` |

Override either, rarely and intentionally, with `--no-verify`.

## Scope (which repos)

**Code repos only:** `ado-mcp`, `ads-qol-extension`, `cc-sentinel`, `.dotfiles`,
`claude-plugins`.

**Excluded:** `brain` (Obsidian PKM vault) and `brain.wiki` — those are
note-taking/wiki repos where direct commits to the default branch are the normal
workflow.

## Enable (per repo)

Point a repo at this hooks directory:

```sh
git -C <repo> config core.hooksPath /absolute/path/to/.dotfiles/git-hooks
```

`core.hooksPath` is per-repo (not global), so enabling it in one repo never
affects another. To turn it off for a repo: `git -C <repo> config --unset core.hooksPath`.

> On Windows, Git runs these via its bundled `sh`, so the POSIX scripts work as-is.
> The files are extensionless and must stay named `pre-commit` / `pre-push`.
