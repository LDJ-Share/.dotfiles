# Authoring & running Windows UIA Appium tests

## Session / fixture lifecycle

A Windows UIA session **launches the app** (Appium `app` capability) and
attaches to its window. Launch is the dominant per-fixture cost, so structure
around **one launch per fixture**, many assertions:

- NUnit: a single `[OneTimeSetUp]` creates the driver; `[Test]` methods share
  it; `[OneTimeTearDown]` quits. Put per-fixture artifact setup (snapshot
  files, seeded data) in the same one-time setup, before driver creation.
- Don't add a second `[OneTimeSetUp]` in a derived fixture — NUnit runs both
  in undefined order. Use a `virtual` hook the base calls.

### Session capabilities (NovaWindows / WinAppDriver)

```csharp
var options = new AppiumOptions {
    AutomationName = "NovaWindows",      // or "Windows" for WinAppDriver
    PlatformName   = "Windows",
    App            = exePath,            // absolute path to the .exe
    DeviceName     = "WindowsPC",
};
options.AddAdditionalAppiumOption("appArguments", "--load-snapshot=...");
var driver = new WindowsDriver(new Uri("http://127.0.0.1:4723"), options);
driver.Manage().Timeouts().ImplicitWait = TimeSpan.FromSeconds(2);
```

- **`ms:waitForAppLaunch` is a literal pre-sleep on NovaWindows, not a
  max-wait.** Setting it to 20 makes every launch sleep 20s. Omit it; the
  driver already polls for the window.
- After attach, assert the window **Title** looks right before any teardown
  `Quit()` — so a mis-attach doesn't close an unrelated window.

### Launch-fast: preloaded state vs. running the workflow

If a test only asserts how a screen **renders**, don't make it drive the full
app workflow (which may run a real or simulated pipeline). Launch the app with
a **preloaded state** flag (`--load-snapshot=<file>`, a seeded DB, a fixture)
so it lands on the populated screen immediately. This is often the difference
between a ~6s test and a ~40s one. Reserve "click Run and wait for the
pipeline" for tests whose *purpose* is that flow.

## Text input

`Clear()`, `Ctrl+A`+type, and `SendKeys` of a full replacement often **don't
fire the WPF data binding** reliably through these drivers (especially on CI).
Use **append-then-trim**:

```csharp
field.SendKeys("desired value" + "x");
field.SendKeys(Keys.Backspace);          // forces a final TextChanged the binding sees
// To clear an existing value first: End, then N× Backspace, then type.
```

## Don't put clickable buttons inside a ComboBox drop-down

A `Button` placed inside a `ComboBoxItem` (e.g. a "＋ create" action in the
drop-down) does **not** reliably receive automation clicks — the ComboBox
consumes the click as item *selection*, so the inner button's `Click`/command
never fires and any dialog it opens never appears. It can pass on a fast clean
CI VM and hang locally. **Put action buttons beside the combo**, not in its
drop-down. (Also better UX.)

## WPF-UI NavigationView: footer items + click that doesn't register

- **`Wpf.Ui` `NavigationView` `FooterMenuItems` don't respond to UIA
  clicks/Enter** on `windows-latest` CI agents (they do locally). Keep any
  nav item a smoke needs to click in `MenuItems`, not `FooterMenuItems`.
- A NavigationView item click sometimes doesn't register through these
  drivers. Make navigation resilient: click, wait briefly for the target; if
  it didn't appear, **re-find the nav item and `SendKeys(Keys.Enter)`** (WPF's
  keyboard pipeline) as a fallback, then wait again.

```csharp
nav.Click();
if (TryWaitForId(targetId, TimeSpan.FromSeconds(5)) is null) {
    WaitForId(navId).SendKeys(Keys.Enter);   // keyboard fallback
    WaitForId(targetId);
}
```

## Don't mutate the window Title to convey state

Desktop-attach (FlaUI, `Quit()` guards, some session reuse) keys off the window
Title. Mutating it mid-session ("Loading…", "3 results") breaks attach
reliability. Keep the Title stable; surface transient state in a status-bar
element with its own AutomationId.

## Category-gate the Appium tests

A fast unit gate that runs "everything except UI" will otherwise pick up your
Appium fixtures, fail to reach the Appium server, and break the build. Tag
every Appium fixture with a category and exclude it from the fast gate:

```csharp
[TestFixture, Category("UiSmoke")]
public sealed class MySmoke : AppiumSmokeBase { ... }
```

```bash
dotnet test --filter "Category!=UiSmoke"     # fast gate
dotnet test --filter "Category=UiSmoke"      # the Appium suite
```

# Running the suite reliably

## NUnit `[Timeout]` cannot interrupt a hung Appium call — use an external kill

A blocked Appium HTTP command (the XPath-walker hang) sits in native socket
code. Modern .NET has no `Thread.Abort`, so NUnit's `[Timeout]`/`TestSessionTimeout`
**reports** a timeout but can't actually stop the stuck thread — the run hangs.
The only reliable cap is an **external wall-clock kill**: run each fixture as
its own `dotnet test` process, wait N seconds, and kill the process tree +
the app + the test host if it overruns. Reusable runner:
[../scripts/run-fixtures-isolated.ps1](../scripts/run-fixtures-isolated.ps1).

Budget ≈ `per-test-seconds × testCount + launch/host overhead` (e.g. 20s/test +
~20s overhead). Anything that hits the kill is your slow/hanging fixture.

## `--filter FullyQualifiedName~X` is a SUBSTRING match

`~Foo` also matches `BarFooTests`, `FooBarTests`, etc. Running one fixture
named `SmokeTests` can silently also run `PlanRunSmokeTests` and
`ResultsSnapshotSmokeTests`. Isolate with the namespace-qualified name and a
**trailing dot**:

```bash
dotnet test --filter "FullyQualifiedName~My.Namespace.SmokeTests."
```

## Clean up zombies between runs

Killed/aborted fixtures leave the app, `testhost`, and sometimes the driver
process alive — and the next run attaches to the wrong window or contends for
UIA. Between fixtures, kill the app exe, `testhost`, `vstest.console`, and any
`dotnet` whose command line targets the UI test project. The runner script does
this; do it manually after a local session too.

## Isolate or reset shared test data

Smokes that write to a **shared app data dir** (snapshots, profiles, recent
files under `%LOCALAPPDATA%`) accumulate debris when killed before cleanup
runs. A list/landing test that expects its 2 fixtures at the top then finds
them buried under 30 leftover entries — and clicks an off-screen/virtualized
row that never selects. Either point the app at a per-run temp dir, or
clear/back-up the shared dir before a local run. Symptom: a row-find or
selection test that passes on CI (clean VM) but fails locally.

## Appium server for a local run

```bash
npx appium --address 127.0.0.1 --port 4723 \
  --log <file> --log-level info:debug --log-timestamp --relaxed-security
```

Start it **without piping to `head`/`tee`** when backgrounding — a closing
pipe sends SIGPIPE and kills the server. The `--log` file is what you read to
find a hang (see optimizing reference).
