---
name: dotnet-style-workflow
description: Use when working in any modern .NET project (C# 12+, dotnet 8+). Stack defaults, code conventions, the ReSharper -> dotnet format -> XAML Styler formatting toolchain, and the csharp-ls LSP reality. Ships copy-able assets (tool manifest, just recipes, changed-files script) so a session with no machine memory can reproduce the workflow.
---

## Purpose

Default stack and workflow opinions for modern C# work, plus the **exact formatting
toolchain** so a session with no memory of this machine can reproduce it. Not
universal C# law — projects committed to other stacks defer to their own conventions.

## Stack defaults (unless the project commits to alternatives)

- **NUnit 4** for tests.
- **CommunityToolkit.Mvvm** for ViewModels (`[ObservableProperty]`, `[RelayCommand]`).
- **Serilog** two-stage bootstrap: `CreateBootstrapLogger()` in the entrypoint, then
  `UseSerilog(ReadFrom.Configuration)` on the host builder.
- **User-secrets** for API keys / secrets — never commit them.

## Code conventions

- `public sealed record` with `required init` properties for DTOs and value types.
- `Nullable` and `ImplicitUsings` enabled in every `.csproj`.
- **Config ownership (keep the three tools from fighting):** `.editorconfig` owns C#
  style; `Settings.XamlStyler` owns XAML; `<Solution>.sln.DotSettings` aligns
  ReSharper to the EditorConfig.

## Formatting workflow (the important part)

Three tools, run in ONE deterministic order — any other order and they undo each
other:

1. **ReSharper CleanupCode** (`jb cleanupcode`) — deepest; applies the DotSettings profile.
2. **`dotnet format`** — EditorConfig-driven whitespace + usings.
3. **XAML Styler** (`xstyler`) — XAML only.

`jb` and `xstyler` are **pinned .NET local tools** — run `dotnet tool restore`
first. Copy `assets/dotnet-tools.json` (jetbrains.resharper.globaltools → `jb`;
xamlstyler.console → `xstyler`) into the repo's `.config/`.

**Format at stable checkpoints, NOT after every edit** — constant churn forces
stale-file rereads and breaks agent flow. Keep formatter-only commits separate from
behavior commits so reviewers skip them at a glance.

### Recipes (copy `assets/justfile.style-snippet` + `assets/style-changed.ps1`)

- `just style` — **changed-files-only** pass: `jb cleanupcode` → `dotnet format` →
  `xstyler`, scoped to files changed vs HEAD.
- `just style-verify` — non-mutating changed-files check.
- `just style-all` / `just style-all-verify` — full-solution, same order.
- `just format-all` / `xaml-format-all` (+ `-verify`) — single-tool passes.
- `just cleanup` — full-solution ReSharper only.
- Without `just`: `dotnet tool restore` then
  `pwsh -NoProfile -File scripts/style-changed.ps1` (add `-Verify` for the check).

### Gotchas (these WILL bite a fresh session)

- **ReSharper has NO passive/verify mode.** `cleanupcode` always mutates; the
  `-verify` recipes SKIP it. A green `style-verify` does NOT prove ReSharper-clean —
  run the mutating `style`/`cleanup` and inspect the diff before pushing.
- **`style-changed.ps1` diffs vs HEAD only** (tracked ACMR + untracked). A
  fully-committed branch shows zero changed files → styles nothing → false "clean."
  Style BEFORE committing, or diff vs `master...HEAD` and run the tools manually.
- **Quote the ReSharper include list:** `"--include=$files"` (semicolon-joined) —
  unquoted, the shell splits it.
- `dotnet format --verify-no-changes` and `xstyler --passive` are the passive checks;
  ReSharper has none (above).

## LSP reality (csharp-ls) — don't chase phantoms

Claude Code's C# LSP is **`csharp-ls`** (razzmatazz), not OmniSharp. If you see
compiler-style errors that `dotnet build -v:minimal` does NOT (CS0103 on
`InitializeComponent`, CS0400/CS1061 on source-gen/gRPC stubs, CS8019/CS8933 on
implicit usings, unresolved CommunityToolkit/DynamicData symbols) — **the LSP is
lying; don't edit code to chase them.** Fixes, in order:

1. `csharp-ls --version`; if < 0.24.0, `dotnet tool update -g csharp-ls` (Windows:
   kill the running `csharp-ls.exe` first — file lock).
2. `.serena/project.yml` must be `languages: ["csharp"]` (default `[]` silently
   no-ops symbol queries).
3. If `.slnx` is the only solution file and phantoms persist on 0.24+, generate a
   sibling classic `.sln`.

**`dotnet build` / `dotnet test` are authoritative.** csharp-ls also shows stale
NUnit diagnostics on test files — ignore them unless `dotnet build` agrees.

## When NOT to use

- Non-.NET projects (the description filter should exclude these).
- C# projects already committed to xUnit / ReactiveUI / NLog / MSBuild-driven
  formatting — defer to project conventions.

### See also

- `verification-before-completion` — the general evidence-over-assertion discipline
  this instances for .NET: run `dotnet build` + `dotnet test` and show the output.
- **dotnet-agent-skills** ([dotnet/skills](https://github.com/dotnet/skills)) — this
  skill owns *formatting + stack defaults*; for the .NET work around it lean on the
  installed dotnet skills: `dotnet-msbuild` (analyzers, code-quality, modernization,
  build-failure diagnosis — beyond pure formatting), `dotnet-test` (run/filter/
  coverage), `dotnet` (core C# mechanics). See the README's "Recommended additional
  skills" for the install line.
