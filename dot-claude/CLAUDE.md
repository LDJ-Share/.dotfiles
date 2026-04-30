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
