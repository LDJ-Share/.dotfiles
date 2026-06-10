# dotnet-style

The .NET-specific companion to the language-agnostic **`dev-workflow`** plugin.
Default stack and workflow opinions for modern C# (C# 12+, dotnet 8+) — applied
when working in a .NET project, deferred to project conventions otherwise.

## Contents

| Kind | Names |
|---|---|
| **skill** | `dotnet-style-workflow` — stack defaults (NUnit 4, CommunityToolkit.Mvvm, Serilog two-stage bootstrap), code conventions (`sealed record` + `required init`, `Nullable`/`ImplicitUsings`), the **ReSharper → dotnet format → XAML Styler** formatting toolchain, format-at-checkpoints discipline, and the csharp-ls LSP reality (don't chase phantoms; trust the build) |

The skill ships **copy-able assets** so a session with no memory of the machine can
reproduce the workflow: `assets/dotnet-tools.json` (pinned `jb` + `xstyler` local
tools), `assets/justfile.style-snippet` (the `style` / `style-all` / `format-all`
recipes), and `assets/style-changed.ps1` (the changed-files pass, with its
diff-vs-HEAD and ReSharper-no-passive-mode gotchas baked in).

## Why a separate plugin

`dev-workflow` is deliberately language-neutral so it's useful on any repo. These
.NET opinions are split out so a Go / Python / Rust user can take the lifecycle
without carrying C# stack defaults. On a .NET repo, install both. The skill's one
"see also" into `verification-before-completion` resolves when `dev-workflow` is also
installed; it's an informational link, not a hard dependency.

## Install

Ships in the dotfiles `matt-dotfiles` marketplace
(`dot-claude/.claude-plugin/marketplace.json`).
