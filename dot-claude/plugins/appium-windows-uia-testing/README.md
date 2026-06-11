# appium-windows-uia-testing

Appium UI-automation testing for Windows desktop apps (WPF/WinUI/Win32) over **UI
Automation (UIA)** — with WinAppDriver or `appium-novawindows-driver`. Three
layers: the **domain skills** (how to write/run/debug fast, reliable UIA tests),
an **orchestration layer** (autonomously *build* a suite of component tests), and a
runnable **`example/`** WPF app + UI-smoke project you can copy from.

## Contents

| Kind | Names |
|---|---|
| **skills** | `appium-windows-uia-setup` (bootstrap the test project + driver + CI into a repo) · `appium-windows-uia-testing` (AccessibilityId-over-XPath, no-UIA-peer placement traps, per-fixture wall-clock-kill runner, Appium debug-log triage, screenshot helper) |
| **command** | `/build-component-tests` — autonomously build a suite of Appium component (UI-smoke) tests |
| **agents** | `scout` (read-only UIA-surface map) · `component-test-builder` (authors tests, compile-only) · `appium-interactive-runner` (the single live-app executor + interactive debugger) · `reviewer` (diff review — is the test real?) |
| **example** | `example/` — a tiny FlightFinder WPF app + UI-smoke project showing the whole setup wired end to end |

## The orchestration layer (component-test build workflow)

`/build-component-tests` runs a triage/cover-style parallel-and-looping workflow,
shaped around the one fact that makes interactive UI tests different from unit
tests: **they can't run in parallel.** Each one launches the app and drives a
single desktop / UIA session, so execution is a serialized bottleneck.

```
orchestrator (/build-component-tests, high-altitude, beads + git)
 ├─ scout            (read-only, parallel)  map the surface, file beads
 ├─ component-test-builder ×N (parallel)    author tests + AutomationIds, compile only
 └─ appium-interactive-runner  ← SINGLETON  the ONLY agent that runs/drives the live
                                            app: executes each test, debugs failures
                                            (locators, log-gap, CPU, screenshots).
                                            Never two at once.
```

**The single-executor invariant.** Exactly one `appium-interactive-runner` is ever
in flight. It is the only agent allowed to start Appium, launch the app, or run the
`UiSmoke` category — and it *is* the verifier (a generic `verifier` must never run
`UiSmoke`, or it would collide). Authoring fans out freely (builders only write
code + `dotnet build`); read-only scouts/reviewers fan out freely; live execution
is serial. Full charter, loop, and gates: [commands/build-component-tests.md](commands/build-component-tests.md).

## Designed for a Sonnet-4.5 / 200k orchestrator

This is the **beads-backed**, ADS-agnostic variant: durable state lives in beads
(`.beads/`) + git, and the orchestrator stays high-altitude so a 200k window is
plenty. All four worker agents (`scout`, `component-test-builder`,
`appium-interactive-runner`, `reviewer`) ship in this plugin — it is **fully
self-contained**, no external dependency to install or explain. It optionally pairs
with the sibling `orchestrator` plugin (same `matt-dotfiles` marketplace), whose
`orchestration-protocol` skill documents beads safety + the Seance log in depth.
The ADS-aware counterpart is the same plugin in the `matt-plugins` marketplace.

## Recommended permissions

The build workflow runs largely unattended, and its `appium-interactive-runner`
does something most plugins don't: it **launches the live app**, drives a real UIA
session, and may `taskkill` zombie Appium/driver processes during cleanup. Those
process-control calls are the ones to think hardest about. An unattended loop also
**deadlocks on the first approval prompt** unless `bd` + your build/test commands
are pre-authorized (see Install below). Drop one tier into the repo's
`.claude/settings.json` under `permissions`, and keep the **safety-net deny** no
matter which tier you pick. Rules evaluate **deny → ask → allow**; *deny always
wins*. Worker subagents (including the runner) inherit these settings.

Pick a tier by trust × autonomy:

- **Low risk** — your own repo, fully unattended suite build. Broad allow incl. app launch + `taskkill`.
- **Medium risk** *(default)* — supervised; auto-authors/builds/runs tests but **asks** before `git commit`/`push`.
- **High risk** — untrusted/shared repo; **asks** before launching the app, running `UiSmoke`, or `taskkill`, and before any mutation.

### Safety-net deny — include in EVERY tier

Blocks secrets/credentials and the most destructive shell regardless of tier.
`Edit` governs all file writes (no separate `Write` domain), so secrets get both a
`Read` and an `Edit` deny; `curl`/`wget` are denied because `WebFetch` rules alone
don't stop shell egress.

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

### Low risk — fully autonomous (trusted personal repo)

```json
{
  "permissions": {
    "allow": [
      "Bash(bd:*)",
      "Bash(appium:*)", "Bash(dotnet build:*)", "Bash(dotnet test:*)",
      "Bash(taskkill:*)",
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(git add:*)", "Bash(git commit:*)",
      "Bash(git checkout:*)", "Bash(git switch:*)", "Bash(git push:*)"
    ]
  }
}
```

### Medium risk — supervised (default)

```json
{
  "permissions": {
    "allow": [
      "Bash(bd:*)",
      "Bash(appium:*)", "Bash(dotnet build:*)", "Bash(dotnet test:*)",
      "Bash(taskkill:*)",
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(git add:*)", "Bash(git checkout:*)", "Bash(git switch:*)"
    ],
    "ask": [
      "Bash(git commit:*)", "Bash(git push:*)"
    ]
  }
}
```

### High risk — locked down (untrusted/shared)

```json
{
  "permissions": {
    "allow": [
      "Bash(bd ready:*)", "Bash(bd show:*)", "Bash(bd list:*)",
      "Bash(dotnet build:*)",
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)"
    ],
    "ask": [
      "Bash(appium:*)", "Bash(dotnet test:*)", "Bash(taskkill:*)",
      "Bash(bd update:*)", "Bash(bd create:*)", "Bash(bd close:*)",
      "Bash(git add:*)", "Bash(git commit:*)", "Bash(git push:*)"
    ]
  }
}
```

> Each tier = the safety-net `deny` **plus** the `allow`/`ask` shown; merge the two
> JSON blocks. Anything matched by no rule prompts by default. The high tier keeps
> app launch (`appium`), live test runs (`dotnet test`, which triggers the
> `UiSmoke` category), and `taskkill` in `ask` — process control is the surface you
> least want unattended on an untrusted repo.

## Install

Installed via the dotfiles `matt-dotfiles` marketplace
(`dot-claude/.claude-plugin/marketplace.json`). To use the build workflow in a repo,
`bd init --stealth` and allowlist `bd` + your build/test commands. No vendoring
needed — the four agents ship with this plugin.

## Recommended additional skills

The `component-test-builder` compiles tests with `dotnet build` and the
`appium-interactive-runner` executes them via `dotnet test` (the `UiSmoke`
category). On those .NET build/test specifics they do better leaning on Microsoft's
official **[dotnet-agent-skills](https://github.com/dotnet/skills)** (the *.NET Team
at Microsoft* marketplace — skills *and* dispatchable agents) than reasoning from
memory. Install the marketplace once:

```
/plugin marketplace add dotnet/skills
/plugin            # install the plugins below
```

Recommended for this workflow:

| Plugin | Reach for it when |
|---|---|
| `dotnet-test` | building a `dotnet test` **filter** for one fixture/category, or detecting the test framework/platform in an unfamiliar repo. |
| `dotnet-msbuild` | a builder's `dotnet build` goes red: build-failure diagnosis and project-file review. |

(UI-automation mechanics — UIA locators, the live-run loop — stay this plugin's own
domain; the dotnet skills only cover the .NET build/test substrate underneath.)
