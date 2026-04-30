---
name: dotnet-style-workflow
description: Use when working in any modern .NET project (C# 12+, dotnet 8+). Captures preferred stack defaults, code conventions, and the format-discipline workflow.
---

## Purpose

Default stack and workflow opinions for new C# work. Not universal C# law — projects already committed to other stacks should defer to their own conventions.

## Behavior

1. **Stack defaults** (use unless the project commits to alternatives):
   - NUnit 4 for tests.
   - CommunityToolkit.Mvvm for ViewModels.
   - Serilog with the two-stage bootstrap pattern: `CreateBootstrapLogger()` in the entrypoint, then `UseSerilog(ReadFrom.Configuration)` on the host builder.
2. **Code conventions:**
   - `public sealed record` with `required init` properties for DTOs and value types.
   - `Nullable` and `ImplicitUsings` enabled in every `.csproj`.
3. **Don't auto-format after every edit.** Format at stable checkpoints. Constant churn forces stale-file rereads and disrupts agent flow.
4. Keep formatter-only commits separate from behavior commits when practical. Reviewers can skip formatter commits at a glance.
5. For verification (CI, pre-push), prefer non-mutating "passive" modes:
   - `dotnet format --verify-no-changes`
   - `xstyler --passive`
   - ReSharper `cleanupcode` has NO passive mode — accept mutation is required for that step.
6. **Standard justfile recipes** (copy into a new project's justfile and adapt paths):
   - `client` — run the WPF or console entry project.
   - `tools` — `dotnet tool restore`.
   - `style` — changed-files-only style pass: `cleanupcode` → `dotnet format` → `xstyler`.
   - `style-verify` — non-mutating changed-files check.
   - `style-all` — full-solution style pass (same chain).
   - `style-all-verify` — non-mutating full-solution check.
   - `format-all` / `format-all-verify` — `dotnet format` solution-wide.
   - `xaml-format-all` / `xaml-format-all-verify` — XamlStyler solution-wide.
   - `cleanup` — `cleanupcode` solution-wide. No `-verify` variant; see #5.
7. **Trust the build, not the LSP.** `csharp-ls` shows stale NUnit and project diagnostics on test files. `dotnet test` is authoritative; don't chase LSP errors on test files unless `dotnet build` agrees.

### When NOT to use

- Non-.NET projects (the description filter should already exclude these).
- C# projects already committed to xUnit, ReactiveUI, NLog, MSBuild-driven formatting, etc. Defer to project conventions.

### See also

- `verification-before-completion` — general "evidence over assertion" discipline this skill instances for .NET.
