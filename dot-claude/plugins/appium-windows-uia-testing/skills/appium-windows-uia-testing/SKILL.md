---
name: appium-windows-uia-testing
description: >-
  Write, run, debug, and speed up Appium UI-automation tests for Windows
  desktop apps (WPF/WinUI/Win32) driven through UI Automation (UIA) — with
  WinAppDriver or appium-novawindows-driver. Use when authoring or fixing
  Appium "UI smoke" tests, when such tests are slow / hanging / flaky / timing
  out, when an element "can't be found" or AutomationId/AccessibilityId lookups
  fail, when a test passes on CI but hangs locally, or when choosing locators
  (AccessibilityId vs XPath). Triggers: "appium", "WinAppDriver",
  "NovaWindows", "UI Automation", "AutomationId", "AccessibilityId",
  "UI smoke test", "FlaUI", flaky/slow/hanging desktop UI test.
---

# Appium Windows UIA Testing

Automating a Windows desktop app with Appium means driving **UI Automation
(UIA)** through a Windows driver — `appium-windows-driver`/**WinAppDriver** or
**`appium-novawindows-driver`** (a pure-PowerShell UIA driver). The single
biggest determinant of whether these tests are fast and reliable vs.
slow/flaky/hanging is **how you locate elements**.

## The one rule that matters most

**Prefer `AccessibilityId` (AutomationId) leaves. Avoid XPath on the deep
visual tree — especially full-tree (`//*`, `.//*`), nested-descendant
(`[.//*[…]]`), `contains()`, or `starts-with()` scans.**

- `MobileBy.AccessibilityId(...)` and `MobileBy.Name(...)` map to native UIA
  `FindFirst`/`FindAll` — effectively instant, even on a huge tree.
- XPath has no native UIA equivalent. The driver **walks the tree itself**
  (NovaWindows does it in PowerShell), which on a deep WPF/WinUI results page
  takes many seconds and, on NovaWindows, intermittently throws
  `Catastrophic failure (Exception from HRESULT: 0x8000FFFF E_UNEXPECTED)`
  mid-walk. A test that does this can hang for 60–160s+ and there is **no
  per-test timeout that will save you** (see Running).

So: **add an `AutomationId` to whatever a test needs to find, count, or click**,
and look it up by `AccessibilityId`. This is the fix for ~90% of slow/hanging
Windows UIA smokes. Full rationale + the placement gotchas:
[references/locators.md](references/locators.md).

| Need | Do | Not |
|------|-----|-----|
| Assert N items exist / count them | one shared `AutomationId` leaf per item, count by `AccessibilityId` | `//*[list item]` / `PlanList/*` |
| Find a specific row by its data | bind `AutomationId="{Binding Key}"`, look up `AccessibilityId(key)` | `//*[…][.//*[@Name='key']]` |
| Confirm a piece of text appeared | `AccessibilityId` on it, or `MobileBy.Name("exact text")` | `driver.PageSource.Contains(...)` |
| Click an action | a real `Button` with an `AutomationId` | a button nested inside a ComboBox drop-down |

## Placement gotcha (causes "element not found" after you add an AutomationId)

`AutomationProperties.AutomationId` on a **`Border`, `Grid`, or `Panel` does
NOT surface to UIA** — those elements get no automation peer, so
`AccessibilityId` can't find them. Put the id on a **peer-bearing** element:
a `TextBlock`, a `Control`, a `UserControl` root, or a templated control. Same
trap for an **inline `<Run>`** inside a `TextBlock` — promote it to its own
`TextBlock`. Details in [references/locators.md](references/locators.md).

## Lifecycle

- **Authoring** fixtures, app launch, text input, isolation, category gating,
  the ComboBox-drop-down-eats-clicks trap, `ms:waitForAppLaunch`, stable
  window title → [references/authoring-and-running.md](references/authoring-and-running.md).
- **Running** the suite: per-fixture **external wall-clock kill** (NUnit
  `[Timeout]` can't interrupt a blocked Appium HTTP call), the `--filter`
  substring trap, process-zombie cleanup, test-data-dir pollution →
  [references/authoring-and-running.md](references/authoring-and-running.md).
  Reusable runner: [scripts/run-fixtures-isolated.ps1](scripts/run-fixtures-isolated.ps1).
- **Debugging / optimizing** a slow or hanging test: enable Appium debug
  logging, find the last command before the gap, identify the offending
  locator, replace it; plus the **CI-passes-but-hangs-locally** dynamic and
  visual verification → [references/optimizing-and-debugging.md](references/optimizing-and-debugging.md).
  Screenshot helper: [scripts/appium-screenshot.ps1](scripts/appium-screenshot.ps1).

## Fast diagnosis when a test hangs or times out

1. **Is the app idle or spinning?** Sample its CPU. Idle + climbing total CPU =
   the driver is crawling the UIA tree (the XPath problem). Truly spinning =
   look at app code.
2. **Read the Appium debug log** (start the server with
   `--log <file> --log-level info:debug --log-timestamp`). Find the **last
   `--> POST .../element(s)` before a long timestamp gap** — that locator is
   the culprit. A nested/`//*` XPath there → convert to `AccessibilityId`.
3. **Confirm it's not the environment**: a fresh, fast CI VM often finishes the
   same slow scan inside the `WebDriverWait`, so the test is "green on CI" but
   hangs on a loaded dev box. Also check for **stale test-data** (snapshots,
   profiles, fixtures) accumulating from prior killed runs and pushing target
   rows off-screen. See [references/optimizing-and-debugging.md](references/optimizing-and-debugging.md).

## Honest framing of an optimization

If the suite was already green on CI, you usually have **no per-fixture CI
timing**. Frame an AccessibilityId conversion as a **local-viability +
fragility** win, not a measured CI-minute saving, unless you actually measured
CI before/after.
