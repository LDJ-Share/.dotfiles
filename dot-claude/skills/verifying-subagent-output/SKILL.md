---
name: verifying-subagent-output
description: After a subagent reports DONE, verify the actual git state and run the project's build/test before trusting. Specifically catches haiku-tier partial edits.
---

## Purpose

Subagents — especially haiku-tier on multi-file refactors — have been observed self-reporting DONE while leaving call sites unupdated, files unstaged, or builds broken. The report is a hypothesis; the diff and the build are the evidence.

## Behavior

1. When a subagent reports DONE on a multi-file task, never accept the report at face value before verification.
2. Run `git status`. Anything unstaged or untracked that wasn't claimed is a red flag.
3. Run `git show --stat <SHA>` (or `git diff --stat HEAD~N..HEAD` for batch dispatches). Compare the actual file footprint against what the task asked for.
4. For interface or signature changes, search for orphaned call sites: `grep -rn '<old-symbol-name>' .` should return zero hits if the change was meant to be global.
5. Run the project's build and test commands. If either fails, the work is not actually done — re-dispatch or fix inline.
6. For haiku-tier dispatches specifically: verification is mandatory, not optional. The failure mode is "I updated all the references" reported while only some were updated.

### See also

- `verification-before-completion` — the general "evidence over assertion" discipline this instances for subagent reports.
- `tiered-subagent-dispatch` — defines when haiku is in play and the verification load is highest.
