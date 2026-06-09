# CI pipeline for Appium Windows UIA smokes

Ready-to-adapt templates:
- GitHub Actions → [../assets/ui-smoke.github.yml](../assets/ui-smoke.github.yml)
- Azure Pipelines / Azure DevOps → [../assets/ui-smoke.azure.yml](../assets/ui-smoke.azure.yml)

Replace the placeholders: `<solution>`, `<UiTestProject path>`, `<app exe
path>`, the .NET/Node versions, and the `Category=UiSmoke` filter.

## The non-negotiable step shape

```
1. Setup .NET SDK
2. Setup Node
3. dotnet build <solution>                         # builds the app + tests
4. dotnet test --filter "Category!=UiSmoke..."     # FAST GATE (no Appium)
5. npm install   (in the UI test dir)              # Appium server + driver
6. ── SINGLE STEP ──
   start Appium (background) -> wait for :4723 -> dotnet test --filter Category=UiSmoke -> stop Appium
7. upload artifacts: appium.log, TRX, diagnostics/  (always / on failure)
```

**Why step 6 must be one step:** every CI step runs in its own shell. On
Windows the shell owns a **job object**; when the step ends, all its child
processes (including a backgrounded Appium) are killed. Start Appium in a
*prior* step and it's dead before the test step connects. So: launch Appium,
poll TCP `127.0.0.1:4723` until ready (≤60s), run the UI `dotnet test` in a
`try`, and `Stop-Process` Appium in a `finally` — all in the same step.

## Artifacts to publish (so failures are debuggable)

| Artifact | When | Why |
|----------|------|-----|
| `appium.log` (`--log-level info`) | always | the only reliable record of *where* a hang happened (test stdout buffers) |
| TRX results | always | per-test pass/fail |
| `diagnostics/` (screenshots + PageSource, videos) | on failure | see the actual UI state at failure |
| app crashlog (if your app writes one) | on failure | native/unhandled crashes |

On **Azure DevOps** also add `PublishTestResults@2` (VSTest, `**/*.trx`) — ADS
has a first-class test viewer; GitHub doesn't, so there you just upload the TRX.

## Gating: don't run slow UI smokes on every push

UI smokes take minutes and (on metered/hosted minutes) add up. Make them
opt-in rather than auto-firing on every PR:

- **Azure DevOps**: `trigger: master` (post-merge) + `pr: none`, and attach the
  pipeline as a **manual Build Validation policy** on the target branch so each
  PR shows a **Queue** button. A two-stage *gate → run* shape (parse an opt-in
  token from the PR description, emit `shouldRun`/`testFilter`) lets you opt a
  PR in and even pick a category subset. Note the **auto-trigger asymmetry**:
  a PR won't queue the pipeline automatically unless the YAML is on the default
  branch or a policy is attached — expect to **manually queue** it on
  migration/first PRs (`az pipelines run` or the run-pipeline API targeting the
  branch ref).
- **GitHub Actions**: use `on: workflow_dispatch` (manual) and/or a
  `pull_request` + `if:` label gate (`contains(github.event.pull_request.labels.*.name, 'ui-smoke')`).

A **manual queue typically bypasses** the opt-in gate by design — that's how you
force a run when you want one.

## Optional polish (only if you record fixture videos)

Hosted Windows agents default to **1024×768**, which crops the app window in
captures. Bump it with `Set-DisplayResolution -Width 1920 -Height 1080 -Force`
(ships with full-framework **Windows PowerShell**, so use a `powershell:` step,
not `pwsh:`). And `ffmpeg` is **not** always preinstalled — `choco install
ffmpeg -y`, then `refreshenv`, then `ffmpeg -version` as a fail-fast canary.
Skip both if you don't record video.

## First-run failure checklist

- "Appium server not reachable" in the **fast gate** → a fixture is missing its
  `Category` attribute and got pulled into the no-Appium run. Tag it.
- "Could not find node_modules/appium/index.js" → `npm install` didn't run in
  the test dir, or ran in the wrong working directory.
- "already installed" → you ran `appium driver install`; remove it (npm install
  auto-discovers the local driver).
- Appium "up" but every test times out attaching → wrong `app` exe path, or the
  window title check doesn't match; print the attached title.
