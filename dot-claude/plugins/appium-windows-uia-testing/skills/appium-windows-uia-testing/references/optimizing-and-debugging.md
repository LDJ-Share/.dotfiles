# Debugging & optimizing a slow / hanging Windows UIA test

## Step 1 — capture an Appium debug log

Restart the server with timestamped debug logging to a file you control:

```bash
npx appium --address 127.0.0.1 --port 4723 \
  --log /tmp/appium.log --log-level info:debug --log-timestamp --relaxed-security
```

Every command is logged as `--> POST /session/<id>/element(s) {...}` with a
timestamp and a session id. **Test stdout buffers and shows nothing when a
fixture is killed**, so the Appium log — not the test output — is your source
of truth for "where did it hang."

## Step 2 — find the last command before the gap

For a hung fixture, scan its session for the **last `--> POST .../element(s)`
whose response arrives many seconds later** (or never, before the kill /
catastrophic-failure line):

```bash
grep -nE "<sessionid>\]\[HTTP\] --> (POST|GET) " /tmp/appium.log
grep -n "Catastrophic failure" /tmp/appium.log
grep -oE '"using":"xpath","value":"[^"]*"' /tmp/appium.log | sort | uniq -c | sort -rn
```

The locator on that command is the culprit. A nested / `//*` / `contains()` /
descendant-by-name XPath there → convert to an `AccessibilityId` leaf
(see locators reference). The `uniq -c` of xpath values quickly shows which
expensive expressions are hit most (often a polling `WebDriverWait` retrying
the same bad XPath dozens of times).

## Step 3 — is the app spinning or idle-waiting?

Sample the app process CPU twice ~1.5s apart:

- **Idle now, but high accumulated total CPU** → the driver is crawling the UIA
  tree (the XPath problem). Fix the locator.
- **Actively spinning** → look at the app itself (an infinite layout pass, a
  busy loop), not the test.

```powershell
$p=Get-Process YourApp; $c1=$p.CPU; Start-Sleep -Milliseconds 1500; $p.Refresh()
"delta {0}s, total {1}s" -f [math]::Round($p.CPU-$c1,2), [math]::Round($p.CPU,1)
```

## Step 4 — rule out environment before "it's a code bug"

Two environment effects masquerade as code bugs:

1. **Green on CI, hangs locally.** A fresh fast CI VM finishes the slow UIA
   scan *inside* the `WebDriverWait` window, so the assertion passes; a loaded
   dev box (background processes, larger tree) tips the same scan into
   timeout / catastrophic failure. The locator is still bad — fix it — but
   don't expect it to reproduce identically everywhere.
2. **Stale shared test data.** Leftover snapshots/profiles/fixtures from
   prior killed runs bury the target row off-screen so a click misses /
   selection never happens. Inspect the app's data dir; clear or isolate it,
   re-run. (See authoring-and-running reference.)

## The optimization itself

Adding an `AutomationId` and switching the lookup to `AccessibilityId` is the
fix. Verify with a **before/after on ONE fixture first** — convert the single
worst offender, re-run it under the wall-clock runner, and confirm e.g.
40s-TIMEOUT → ~9s-PASS before touching the other N. Then roll out.

### Watch for non-count uses of a shared helper

If a shared helper returned list-item *containers* and tests both **count**
them and **search within** them (`items[0].FindElements(...)`) or read their
`.Text`, your replacement must preserve that. Options:
- Put the AutomationId on the **item root** (UserControl) so it's both
  countable and a valid search scope.
- For a per-item value used in a signature/assertion, add a child-leaf
  AutomationId (e.g. `ItemKey`, `ItemScore`) and read it scoped to the item
  (`item.FindElement(MobileBy.AccessibilityId("ItemKey")).Text`) — a small,
  fast subtree search.

### Honest framing

If the suite was already green on CI you have **no per-fixture CI timing**, so
report the win as **local-viability + reduced fragility**, not measured
CI-minute savings, unless you actually measured CI before/after.

## Visual verification of a UI fix

When the fix is visual (an icon now renders, a control moved), prove it with a
screenshot rather than asserting from the tree. Drive the app via the Appium
REST API to the relevant state and capture `GET /session/<id>/screenshot`
(base64 PNG): [../scripts/appium-screenshot.ps1](../scripts/appium-screenshot.ps1).
Pick a launch state you can reach in a few clicks (a preloaded snapshot avoids
a full workflow).

## WPF-UI (`Wpf.Ui`) note — empty `ui:Button` icons

If a `ui:Button` shows its glyph via the `Icon` property and you give it an
inline `Style` with `BasedOn="{StaticResource {x:Type Button}}"`, you swap in
the **plain** `Button` template (no Icon presenter) and the icon renders empty.
Base on `{x:Type ui:Button}` instead. (A `ui:Button` whose visual is set via
`Content`, e.g. a `MaterialIcon` child, renders fine under either base —
don't change those.) Not strictly an automation issue, but it surfaces while
auditing why a templated control "shows nothing" in a UI test.
