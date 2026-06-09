# Flight Finder — Appium NovaWindows UI-automation sample

A small, self-contained **WPF + Appium** demo showing how to drive a Windows
desktop app through **UI Automation (UIA)** with the
[`appium-novawindows-driver`](https://github.com/cnaize/appium-novawindows-driver)
(pure-PowerShell — **no WinAppDriver.exe install**).

It's the worked example for the **`appium-windows-uia-testing`** skill: the base
fixture and CI YAML here are that skill's genericized templates with their
placeholders filled in, so this is literally "what you get when you follow the
skill." If you're coming from **WinAppDriver / Windows Application Driver**,
start with **[MIGRATION.md](MIGRATION.md)** — that's the point of this sample.

> The app is a generic flight-search UI (origin → destination → ranked results
> → open one). It does no real flight lookup; the data is fixed so the smokes
> are deterministic.

## What it demonstrates

| Concept | Where |
|---|---|
| Driver lifecycle, one launch per fixture, attach-to-right-window guard | `tests/.../Infrastructure/AppiumSmokeBase.cs` |
| `AccessibilityId` over XPath; **shared** id to count rows, **unique** data-bound id to target one | `MainWindow.xaml` + `SearchSmokeTest.cs` |
| The "AutomationId on a Border/Grid/Panel doesn't surface" placement trap | comments in `MainWindow.xaml` |
| Trivial first smoke that proves the whole pipeline | `LaunchSmokeTest.cs` |
| `appArguments` capability + `launchSettings.json` parity | `PreloadedResultsSmokeTest.cs` + `Properties/launchSettings.json` |
| Two-pass test gate: fast unit gate (no Appium) then the UI pass | `FlightResultTests.cs` (no category) vs the `[Category("UiSmoke")]` fixtures |
| Append+backspace text input (Clear()/Ctrl+A don't fire WPF bindings via UIA) | `Infrastructure/AppiumInput.cs` |
| Click-with-keyboard-Enter fallback for stubborn nav items | `AppiumSmokeBase.ClickNavAndWait` |
| CI that builds, runs the fast gate, starts Appium, runs the smokes, uploads diagnostics | `ci/github-ui-smoke.yml`, `ci/azure-ui-smoke.yml` |

## Layout

```
example/
├─ FlightFinder.sln
├─ src/FlightFinder.App/            # generic WPF app under test
│  ├─ MainWindow.xaml(.cs)          # AutomationIds live here
│  ├─ MainViewModel.cs / FlightResult.cs
│  └─ Properties/launchSettings.json  # has a "(preload)" profile = the --preload smoke
├─ tests/FlightFinder.UiTests/      # NUnit + Appium
│  ├─ Infrastructure/AppiumSmokeBase.cs   # skill template, placeholders resolved
│  ├─ Infrastructure/AppiumInput.cs
│  ├─ LaunchSmokeTest.cs / SearchSmokeTest.cs / PreloadedResultsSmokeTest.cs
│  ├─ FlightResultTests.cs          # plain unit test (fast gate)
│  └─ package.json                  # appium + appium-novawindows-driver
├─ ci/github-ui-smoke.yml           # drop into .github/workflows/ in a real repo
├─ ci/azure-ui-smoke.yml            # an Azure Pipelines pipeline
└─ scripts/run-ui-smokes.ps1        # local one-shot runner
```

## Prerequisites

- **.NET 10 SDK** (the projects target `net10.0-windows`).
- **Node.js** (for the Appium server + driver). v20+ is fine.
- **Windows.** UIA automation only runs on Windows.

## Build

```pwsh
dotnet build FlightFinder.sln --configuration Debug
```

## Run the fast gate (no Appium needed)

```pwsh
dotnet test FlightFinder.sln --no-build --filter "Category!=UiSmoke"
```

This runs only the plain unit tests (`FlightResultTests`). The UI smokes are
excluded so the gate never tries to reach an Appium server that isn't running.

## Run the UI smokes

One command does the whole dance (build → install driver → start Appium → run
the `UiSmoke` filter → stop Appium):

```pwsh
pwsh -NoProfile -File scripts/run-ui-smokes.ps1
```

Or by hand:

```pwsh
cd tests/FlightFinder.UiTests
npm install                       # installs appium + the driver; do NOT 'appium driver install'
npx appium --log-level info       # leave running in this terminal
# in another terminal, from the sample root:
dotnet test FlightFinder.sln --no-build --filter "Category=UiSmoke"
```

> UI smokes are happiest on a clean, idle machine — a UIA scan can crawl on a
> loaded dev box, which reads as "green on CI but hangs locally." That's
> environmental, not a regression. See the skill's
> `optimizing-and-debugging.md`.

## CI

`ci/github-ui-smoke.yml` and `ci/azure-ui-smoke.yml` are ready pipelines (paths
assume this sample's directory is the repo root). Both:

1. build the solution,
2. run the fast gate (no Appium),
3. `npm install` the driver,
4. **start Appium + run the smokes in a single step** — Windows tears down a
   backgrounded Appium when a step's shell exits, so they must share one shell,
5. upload the Appium log, TRX results, and failure diagnostics (screenshot +
   PageSource).

They're gated to manual/opt-in runs because UI smokes are slow — see the
comments in each file and the skill's `ci-pipeline.md`.

## AutomationId catalog

| AutomationId | Element | Used for |
|---|---|---|
| `NavSearch`, `NavAbout` | nav buttons | `ClickNavAndWait` demo |
| `SearchOriginInput`, `SearchDestinationInput` | text boxes | append+backspace input |
| `SearchButton` | button | trigger search |
| `ResultCountText` | text block | read status text |
| `ResultsList` | list view | container |
| `ResultCard` | per-row text block (**shared**) | count rows by `FindElements` |
| `OpenResult_{Id}` | per-row button (**unique**, data-bound) | target one row |
| `AboutPageRoot` | text block | nav target |

## See also

- **[MIGRATION.md](MIGRATION.md)** — migrating from WinAppDriver to NovaWindows.
- The **`appium-windows-uia-testing`** and **`appium-windows-uia-setup`** skills
  (this plugin) — the prose behind every pattern here.
