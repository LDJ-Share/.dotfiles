# Migrating from WinAppDriver to appium-novawindows-driver

You already have Appium UI smokes running on **Windows Application Driver**
(`appium-windows-driver`, `AutomationName = "Windows"`), and you want to move to
**`appium-novawindows-driver`** (`AutomationName = "NovaWindows"`). Both drive
the same Win32 **UI Automation (UIA)** APIs, so your locators and most of your
test code are unchanged. What changes is **how the driver is installed and
hosted**, plus a handful of behavioral quirks worth knowing up front.

This sample is already on NovaWindows; this document is the diff you'd apply to
a WinAppDriver project to get here.

## Why move

| | WinAppDriver (`Windows`) | NovaWindows (`NovaWindows`) |
|---|---|---|
| Extra install on the agent | `WinAppDriver.exe` (a separate MSI / service) | **none** — pure PowerShell, ships as an npm package |
| How it's provisioned | install the MSI, start the service on port 4723/4724 | `npm install` (a `devDependency`) |
| Hosted-CI friendliness | must install + launch WinAppDriver per run | just `npm install` + start Appium |
| Maintenance | last meaningful release was years ago | actively maintained |
| Driver | a binary you manage | discovered automatically by Appium from `node_modules` |

The headline win: **no `WinAppDriver.exe` to install or keep alive.** On a hosted
Windows agent that removes a flaky, privileged setup step.

## The actual code change

### 1. The capability

```diff
 var options = new AppiumOptions
 {
-    AutomationName = "Windows",
+    AutomationName = "NovaWindows",
     PlatformName = "Windows",
     App = exePath,
     DeviceName = "WindowsPC",
 };
```

That's the only required change to your fixture. `WindowsDriver`,
`AppiumOptions`, `MobileBy.AccessibilityId(...)`, `WebDriverWait`, etc. are all
the same Appium .NET client — see `tests/.../Infrastructure/AppiumSmokeBase.cs`.

### 2. Install: `package.json`, not an MSI

Drop the WinAppDriver MSI install / service-start steps. Add the driver as a
local devDependency (see `tests/FlightFinder.UiTests/package.json`):

```json
{
  "private": true,
  "scripts": { "appium": "appium" },
  "devDependencies": {
    "appium": "^3.0.0",
    "appium-novawindows-driver": "^1.4.0"
  }
}
```

Then **`npm install`** — it installs the server AND auto-discovers the local
driver. **Do not** run `appium driver install novawindows`; with the driver as a
local dependency that errors with "already installed" (a classic first-CI-run
break).

### 3. Drop the WinAppDriver service step

With WinAppDriver you typically start `WinAppDriver.exe` (the UIA backend) AND
the Appium server. With NovaWindows there's no separate backend — you only start
**Appium**, and the driver runs in-process. The CI step becomes just "start
Appium, wait for port 4723, run tests" (see `ci/*.yml`).

## Behavioral differences to plan for

These are the things that bite when the code compiles but a test misbehaves.

### `ms:waitForAppLaunch` is a literal pre-sleep on NovaWindows

On WinAppDriver this capability is a *max-wait*. On NovaWindows (≤ 1.4.x) it's a
literal **pre-sleep** before the driver even looks for the window — so a value
like `25` just adds 25s of dead time. **Omit it**; NovaWindows already polls for
the launched window. (This sample sets no such capability.)

### Locator discipline is stricter — lean harder on AccessibilityId

Both drivers map `AccessibilityId` / `Name` to native UIA `FindFirst`/`FindAll`
(fast). But XPath has no native UIA equivalent — the driver walks the tree
itself, and **NovaWindows does that walk in PowerShell**. On a deep WPF tree a
full-tree / nested-descendant / `contains()` XPath can take many seconds and
intermittently throw:

```
Catastrophic failure (Exception from HRESULT: 0x8000FFFF E_UNEXPECTED)
```

mid-walk, with no per-test timeout that can save you. If you carried over any
XPath locators from WinAppDriver, **convert them to `AccessibilityId`** as part
of the migration. Add an `AutomationId` to anything a test must find, count, or
click. (See `MainWindow.xaml` + `SearchSmokeTest.cs` for the shared-id-to-count
and unique-id-to-target patterns.)

### Transient `PSInt32Array` / NaN errors while WPF is laying out

Because the driver is PowerShell, you can see transient `WebDriverException`s
(e.g. `PSInt32Array` / NaN) thrown from `FindElements` *while WPF is still
measuring/arranging* freshly-rendered content. Don't fail on the first one —
poll past it:

```csharp
wait.Until(_ =>
{
    try { return Driver.FindElements(MobileBy.AccessibilityId("ResultCard")).Count > 0; }
    catch (WebDriverException) { return false; } // transient mid-layout fault
});
```

### Some clicks need a keyboard-Enter fallback

A physical mouse click on certain WPF controls (notably WPF-UI
`NavigationView` footer items on `windows-latest`) doesn't always register
through NovaWindows. Send `Keys.Enter` as a fallback — that's what
`AppiumSmokeBase.ClickNavAndWait` does.

### Text input: append + backspace, not `Clear()` / Ctrl+A

`Clear()` and a Ctrl+A + Delete sequence don't reliably fire WPF's TwoWay
binding through NovaWindows on CI — the bound property silently keeps its old
value. Set text by appending then backspacing over the prior value so each key
goes through WPF's input pipeline. See `Infrastructure/AppiumInput.cs`.

### Elements with no UIA peer still don't surface (same as WinAppDriver)

Not new, but easy to trip on while you're touching locators:
`AutomationProperties.AutomationId` on a **`Border`, `Grid`, or `Panel` gets no
UIA peer**, so `AccessibilityId` can't find it. Put the id on a peer-bearing
element (`TextBlock`, `Control`, `UserControl` root). Inline `<Run>` has the same
problem — promote it to its own `TextBlock`.

## Migration checklist

1. [ ] Flip `AutomationName` from `"Windows"` to `"NovaWindows"`.
2. [ ] Add `appium` + `appium-novawindows-driver` to the test project's
       `package.json` devDependencies; remove WinAppDriver MSI/service steps.
3. [ ] Switch CI to `npm install` (not `appium driver install`) and a single
       "start Appium → run smokes" step (no separate WinAppDriver launch).
4. [ ] Remove any `ms:waitForAppLaunch` capability.
5. [ ] Audit locators: convert XPath (especially `//*`, nested-descendant,
       `contains()`) to `AccessibilityId`; add AutomationIds where missing.
6. [ ] Wrap `FindElements` in your populate-waits to swallow transient
       PowerShell faults.
7. [ ] Add a keyboard-Enter fallback to nav/menu clicks that don't register.
8. [ ] Replace `Clear()`/`Ctrl+A` text entry with append+backspace.
9. [ ] Run the suite on a clean agent; treat first-run slowness as
       environmental before assuming a regression.

Everything above is implemented in this sample — diff your project against it.
