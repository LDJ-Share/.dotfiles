---
description: Wrap up a development branch — verify tests, run a final review, then choose merge / PR / keep / discard.
argument-hint: [base branch, optional]
---
Wrap up the current branch. First run a `final-branch-review` (opus over
`master..HEAD`, or the base given in $ARGUMENTS) to catch cross-task issues, fix any
CRITICAL findings, then invoke the `finishing-a-development-branch` skill.

Verify tests pass before presenting options; present exactly four (merge / PR /
keep / discard); require typed confirmation for discard; clean up the worktree only
on merge and discard.
