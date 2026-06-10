---
name: verification-before-completion
description: Before claiming any work is complete (commit, PR, "task done"), run the project's actual build/test/lint commands and confirm output. Evidence over assertion.
---

## Purpose

Model self-reports without verification are unreliable. "Tests pass" is a hypothesis; the actual command output is the evidence. Run the commands.

## Behavior

1. Before declaring any non-trivial task done, run the project's actual verification commands. Whatever the project conventionally uses: `go test ./...`, `dotnet test`, `npm test`, `pytest`, `cargo test`.
2. Also run the project's build (`go build`, `dotnet build`, `npm run build`, `cargo build`). Passing tests don't catch type errors that the runtime never reaches.
3. Show evidence in the report: exit code, summary line ("9/9 PASS"), or a relevant output snippet. Don't claim "tests pass" without showing it.
4. If verification reveals problems, do not paper over them or downgrade the claim ("works locally"). Fix or surface.
5. For multi-language projects, run all relevant verifications. A project with both Go and C# components needs both `go test` and `dotnet test`.

### See also

- `verifying-subagent-output` — related discipline applied to subagent reports specifically.
