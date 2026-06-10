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

## Install

Installed via the dotfiles `matt-dotfiles` marketplace
(`dot-claude/.claude-plugin/marketplace.json`). To use the build workflow in a repo,
`bd init --stealth` and allowlist `bd` + your build/test commands. No vendoring
needed — the four agents ship with this plugin.
