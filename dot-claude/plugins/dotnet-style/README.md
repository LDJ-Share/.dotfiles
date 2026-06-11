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

## Recommended permissions

The whole point of this plugin is to run formatters — `dotnet format`, ReSharper
`jb cleanupcode`, and `xstyler` — which **rewrite source files in place**. So the
permission to think about is "may a formatter mutate the tree unattended?" The
passive `*-verify` recipes only *report*, so they're always safe to allow; the
mutating ones are what the high tier gates. Drop one tier into the repo's
`.claude/settings.json` under `permissions`, and keep the **safety-net deny** no
matter which tier you pick. Rules evaluate **deny → ask → allow**; *deny always
wins*.

Pick a tier by trust × autonomy:

- **Low risk** — your own repo. Let the toolchain (incl. `pwsh` scripts) run freely.
- **Medium risk** *(default)* — formatters run, but **asks** before `git commit`/`push`.
- **High risk** — untrusted/shared repo; only the passive `*-verify` checks + build/test run, **asks** before any mutating formatter or git write.

### Safety-net deny — include in EVERY tier

Blocks secrets/credentials and the most destructive shell regardless of tier.
`Edit` governs all file writes (there is no separate `Write` domain), so secrets
get both a `Read` and an `Edit` deny; `curl`/`wget` are denied because `WebFetch`
rules alone don't stop shell egress.

```json
{
  "permissions": {
    "deny": [
      "Read(.env)", "Edit(.env)",
      "Read(.env*)", "Edit(.env*)",
      "Read(**/secrets/**)", "Edit(**/secrets/**)",
      "Read(**/*.pem)", "Edit(**/*.pem)",
      "Read(**/*.key)", "Edit(**/*.key)",
      "Read(**/*.pfx)", "Edit(**/*.pfx)",
      "Read(**/id_rsa*)", "Edit(**/id_rsa*)",
      "Read(~/.ssh/**)", "Edit(~/.ssh/**)",
      "Read(~/.aws/**)", "Edit(~/.aws/**)",
      "Read(~/.config/gh/**)", "Edit(~/.config/gh/**)",
      "Edit(**/.git/**)",
      "Bash(rm -rf:*)", "Bash(rm -fr:*)",
      "Bash(sudo:*)",
      "Bash(curl:*)", "Bash(wget:*)",
      "Bash(git push --force:*)", "Bash(git push -f:*)"
    ]
  }
}
```

### Low risk — trusted personal repo

```json
{
  "permissions": {
    "allow": [
      "Bash(dotnet:*)", "Bash(just:*)", "Bash(jb:*)", "Bash(xstyler:*)",
      "Bash(pwsh:*)",
      "Bash(git status:*)", "Bash(git diff:*)",
      "Bash(git add:*)", "Bash(git commit:*)"
    ]
  }
}
```

### Medium risk — supervised (default)

```json
{
  "permissions": {
    "allow": [
      "Bash(dotnet tool restore:*)", "Bash(dotnet format:*)",
      "Bash(dotnet build:*)", "Bash(dotnet test:*)",
      "Bash(jb:*)", "Bash(xstyler:*)",
      "Bash(just style:*)", "Bash(just style-verify:*)",
      "Bash(just style-all:*)", "Bash(just style-all-verify:*)",
      "Bash(pwsh -NoProfile -File scripts/style-changed.ps1:*)",
      "Bash(git status:*)", "Bash(git diff:*)"
    ],
    "ask": [
      "Bash(git add:*)", "Bash(git commit:*)", "Bash(git push:*)"
    ]
  }
}
```

### High risk — locked down (untrusted/shared)

```json
{
  "permissions": {
    "allow": [
      "Bash(dotnet build:*)", "Bash(dotnet test:*)",
      "Bash(just style-verify:*)", "Bash(just style-all-verify:*)",
      "Bash(git status:*)", "Bash(git diff:*)"
    ],
    "ask": [
      "Bash(dotnet format:*)", "Bash(jb:*)", "Bash(xstyler:*)", "Bash(pwsh:*)",
      "Bash(git add:*)", "Bash(git commit:*)"
    ]
  }
}
```

> Each tier = the safety-net `deny` **plus** the `allow`/`ask` shown; merge the two
> JSON blocks. Anything matched by no rule prompts by default. The high tier
> deliberately allows only the passive `*-verify` recipes and routes every mutating
> formatter through a prompt — on an untrusted repo you want to *see* the rewrite
> before it touches the tree. (`just style` / `just style-all` are intentionally
> **not** in `ask`: rule matching is a character-level prefix, so a `just style:*`
> rule would also match `just style-verify` and gate the passive checks. Left
> unlisted, the mutating recipes still prompt by default while the `*-verify`
> `allow` entries take effect.)

## Install

Ships in the dotfiles `matt-dotfiles` marketplace
(`dot-claude/.claude-plugin/marketplace.json`).

## Recommended additional skills

This plugin owns the **style/formatting** layer (ReSharper → `dotnet format` → XAML
Styler) and stack defaults. For the .NET work *around* that — writing code, fixing
builds, modernizing — pair it with Microsoft's official
**[dotnet-agent-skills](https://github.com/dotnet/skills)** (the *.NET Team at
Microsoft* marketplace — skills *and* dispatchable agents), which handle those far
better than reasoning from memory. Install the marketplace once:

```
/plugin marketplace add dotnet/skills
/plugin            # install the plugins below
```

Recommended companions:

| Plugin | Reach for it when |
|---|---|
| `dotnet` | core C# mechanics that the conventions here assume (scripts, P/Invoke, common patterns). |
| `dotnet-msbuild` | code-quality / analyzer / modernization work and build-failure diagnosis — the layer beyond pure formatting. |

(Formatting itself stays this plugin's `dotnet-style-workflow` skill —
`dotnet-msbuild` complements it on analyzers and project-file quality, it doesn't
replace the toolchain.)
