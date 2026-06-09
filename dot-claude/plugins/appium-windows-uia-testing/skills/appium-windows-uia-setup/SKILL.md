---
name: appium-windows-uia-setup
description: >-
  Bootstrap Appium UI-automation testing into a Windows desktop repo
  (WPF/WinUI/Win32) that doesn't have it yet — scaffold the test project,
  install Appium + a Windows UIA driver, add a base fixture, wire category
  gating, and stand up a CI pipeline (GitHub Actions or Azure Pipelines /
  Azure DevOps) that builds the app, starts Appium, runs the UI smokes, and
  uploads diagnostics. Use when a repo has NO UI/UIA tests yet and you need to
  add the first one end to end, when asked to "set up / add / scaffold Appium
  UI tests", create a "UI smoke project", or "add a UI-test CI pipeline" for a
  Windows desktop app. For writing/fixing/optimizing tests once the harness
  exists, use the companion skill `appium-windows-uia-testing` instead.
---

# Bootstrap Appium Windows UIA testing into a repo

Stand up Appium UI-automation for a Windows desktop app from zero: a test
project, the Appium server + a Windows **UI Automation (UIA)** driver, a base
fixture, and a CI pipeline. Once it runs, author tests with the companion skill
**`appium-windows-uia-testing`** (locators, debugging, optimizing).

## End-to-end checklist

1. **Pick the UIA driver.**
   - **`appium-novawindows-driver`** — pure-PowerShell UIA; **no WinAppDriver
     install** needed. Easiest on hosted CI. (`AutomationName = "NovaWindows"`.)
   - **`appium-windows-driver`** (Microsoft WinAppDriver) — needs
     `WinAppDriver.exe` installed/running. (`AutomationName = "Windows"`.)
   Default to NovaWindows on hosted agents to avoid the WinAppDriver install.
2. **Create the test project** — `net<ver>-windows` TFM, `Appium.WebDriver` +
   NUnit (or xUnit), `IsTestProject=true`, and exclude `node_modules/**` from
   the build globs. → [references/test-project.md](references/test-project.md).
3. **Add `package.json`** pinning `appium` + the driver as **devDependencies**;
   `npm install` auto-discovers a local driver — **do not** run
   `appium driver install` (it errors "already installed"). → same reference.
4. **Add a base fixture** (`AppiumSmokeBase`) owning the driver lifecycle +
   `AccessibilityId` helpers. Copy [assets/AppiumSmokeBase.cs](assets/AppiumSmokeBase.cs)
   and adjust the app-exe path + namespace.
5. **Category-gate** every Appium fixture (e.g. `[Category("UiSmoke")]`) so the
   fast unit gate (`--filter "Category!=UiSmoke"`) doesn't pull it in and crash
   trying to reach Appium.
6. **Write the first smoke** — launch, find one element by `AccessibilityId`,
   assert. Keep it tiny; prove the pipeline before adding more.
7. **Stand up CI** → [references/ci-pipeline.md](references/ci-pipeline.md) and
   the ready templates [assets/ui-smoke.github.yml](assets/ui-smoke.github.yml)
   / [assets/ui-smoke.azure.yml](assets/ui-smoke.azure.yml).

## The gotchas that will bite a first-timer

- **Start-Appium and run-tests MUST be a single CI step.** Each CI step runs in
  its own shell; the Windows **job object tears down child processes when the
  step's shell exits**, so an Appium started in a prior step is dead before the
  test step connects. Launch Appium (background process), wait for port 4723,
  run `dotnet test --filter Category=UiSmoke`, then stop Appium — all in one
  step (the templates do this).
- **Two test passes, not one.** Run the **fast gate first**
  (`--filter "Category!=UiSmoke&Category!=DocsCapture"`, no Appium), then the
  **UI pass** (`--filter "Category=UiSmoke"`, after Appium is up). A single
  combined run would try to launch the app for unit tests too.
- **`npm install`, not `appium driver install`.** A driver listed as a local
  devDependency is auto-discovered; the explicit install command fails on the
  second run.
- **Exclude `node_modules/**`** from `Compile`/`Content`/`None`/`EmbeddedResource`
  or the build chokes on the driver's JS.
- **A loaded local box ≠ a clean CI VM.** UIA scans are slower locally; expect a
  test that's green on CI to occasionally hang on a busy dev machine. (This is
  why the companion skill pushes `AccessibilityId` over XPath.)

## CI shape decisions

- **Hosted Windows agent**: GitHub `windows-latest` / Azure `windows-2022`.
- **Toolchain**: install the matching .NET SDK and Node; `dotnet build`; fast
  gate; `npm install` in the test dir; the single Appium+UI step.
- **Artifacts** (always/on-failure): the **Appium debug log**, the **TRX**
  results, and a **diagnostics** dir (failure screenshots + PageSource, and
  video if you record). On Azure DevOps also add `PublishTestResults@2` for the
  first-class test viewer.
- **Cost control / opt-in**: UI smokes are slow (minutes). Gate them — don't run
  on every PR push by default. On Azure DevOps, `pr: none` + attach the pipeline
  as a **manual Build Validation policy** so PRs show a "Queue" button (a manual
  queue bypasses the gate). On GitHub, use `workflow_dispatch` or a label gate.
  See [references/ci-pipeline.md](references/ci-pipeline.md).
- **Optional polish**: bump desktop resolution (hosted agents default to
  1024×768) and install `ffmpeg` only if you record fixture videos.

## A complete worked example

A full, buildable sample that instantiates everything above — a WPF app under
test, the base fixture + smokes, both CI YAMLs, and a WinAppDriver→NovaWindows
migration guide — lives at [`../../example/`](../../example/) (see its
`README.md` and `MIGRATION.md`). It's the resolved, runnable form of these
templates; diff your project against it.
