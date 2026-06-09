# Locators: AccessibilityId first, XPath as a last resort

## Why XPath is dangerous on Windows UIA

UIA exposes native `FindFirst`/`FindAll` keyed on a handful of properties —
`AutomationId`, `Name`, `ControlType`, `ClassName`. Appium maps these to:

- `MobileBy.AccessibilityId(x)` → UIA `AutomationId == x` (native, fast)
- `MobileBy.Name(x)` → UIA `Name == x` (native, fast)
- `By.ClassName`, `By.TagName` → native ControlType/ClassName (fast)

**XPath has no native equivalent.** The driver materializes and walks the
element tree itself to evaluate the expression:

- **WinAppDriver**: walks via UIA COM; `//*`/descendant axes force a full
  subtree expansion — slow on a large tree.
- **`appium-novawindows-driver`**: evaluates XPath in a **PowerShell** script
  that calls `GetCurrentPropertyValue` per node. On a deep WPF/WinUI results
  tree this takes many seconds, and the COM walk intermittently dies with
  `Exception calling "GetCurrentPropertyValue" with "1" argument(s):
  "Catastrophic failure (Exception from HRESULT: 0x8000FFFF E_UNEXPECTED)"`
  — usually because the visual tree is being re-virtualized/measured under it.

The expensive shapes, worst first:

| Shape | Example | Why bad |
|-------|---------|---------|
| nested descendant predicate | `.//*[@LocalizedControlType='dataitem' and .//*[starts-with(@Name,'Score:')]]` | O(n·m) walk + per-node property reads |
| full-tree scan | `//*[contains(@Name,'BHM')]` | expands the entire window subtree |
| descendant-by-name | `.//*[@Name='row_key']` (rooted at driver) | full subtree, per-node Name read |
| `contains()` / `starts-with()` | any | forces string property read per node |

A shallow, AutomationId-anchored XPath against a *small* subtree
(`//*[@AutomationId='StatusBadge']` on a simple page) is usually fine — it's
the **deep result/list/grid trees** that blow up. When in doubt, measure (see
optimizing reference).

## The fix: add an AutomationId leaf, look it up by AccessibilityId

### Count items / assert "≥1 exists"

Give every item the **same** AutomationId on a peer-bearing element of its
template, then count:

```xml
<!-- item template root (a UserControl gets an automation peer) -->
<UserControl ... AutomationProperties.AutomationId="ResultCard"> ... </UserControl>
```

```csharp
int count = container.FindElements(MobileBy.AccessibilityId("ResultCard")).Count;
```

AutomationIds need **not** be unique — `FindElements` returns all matches.
Put it on the item root if tests also need each item as a **search scope**
(e.g. `card.FindElements(...)` for children) — a childless leaf like a Score
`TextBlock` can be counted but can't be searched within.

### Find a specific row by its data

Bind the AutomationId to the row's stable key:

```xml
<TextBlock AutomationProperties.AutomationId="{Binding DisplayName}" Text="{Binding PrimaryText}" />
```

```csharp
var row = TryWaitForId(displayName, TimeSpan.FromSeconds(10)); // AccessibilityId under the hood
row.Click();
```

Note the AutomationId value is independent of the displayed `Text` — the
TextBlock can show a timestamp while its AutomationId carries the key.

### Confirm specific text appeared (instead of PageSource)

`driver.PageSource` serializes the **entire** UIA tree to XML — expensive on a
deep tree and a common hidden cost. Replace `PageSource.Contains("Header")`
with a native lookup:

```csharp
// static text exposes UIA Name == its Text
wait.Until(d => d.FindElements(MobileBy.Name("Search Window")).Any());
// or, more robustly, add an AutomationId to the header and TryWaitForId it
```

### Combobox / dropdown options

Bind each option's AutomationId to its code/key, then resolve + assert its text:

```xml
<TextBlock AutomationProperties.AutomationId="{Binding Code, StringFormat=Option_{0}}" Text="{Binding Label}" />
```

```csharp
var opt = WaitForElement(d => d.FindElements(MobileBy.AccessibilityId("Option_BHM")).FirstOrDefault());
Assert.That(opt.Text, Does.Contain("mi"));   // keeps the "shows metadata" assertion
opt.Click();
```

## Placement gotchas — why an AutomationId you added still isn't found

WPF only puts an element in the UIA tree if it has an **automation peer**.

| Element | Gets a peer? | Use for AutomationId? |
|---------|--------------|------------------------|
| `Border`, `Grid`, `StackPanel`, `Panel` | **No** (by default) | ❌ AccessibilityId can't find it |
| inline `<Run>` inside a `TextBlock` | **No** | ❌ promote to its own `<TextBlock>` |
| `TextBlock`, `Control`, `Button`, `ListBoxItem` | Yes | ✅ |
| `UserControl` root | Yes (UserControlAutomationPeer) | ✅ — great per-item search root |

So: if `AccessibilityId(x)` times out right after you added the id, check you
didn't put it on a `Border`/`Grid`/`Panel` or an inline `<Run>`. Move it to a
`TextBlock`/`Control`/`UserControl`.

To set it on a **container** without nesting, use an `ItemContainerStyle`
(sets `AutomationProperties.AutomationId` on the generated `ListBoxItem`, which
has a peer) — or just put it on a child `TextBlock`; clicking that child still
selects the row.

## Data-bound ListItem.Name is the VM type name

A data-bound `ListBoxItem`/`ListViewItem`'s UIA **Name defaults to the
ViewModel's `ToString()`** (often the type name), not its visible text. So
`MobileBy.Name("My Row Label")` on the *item* fails; the label lives on a
descendant `TextBlock`. Prefer an explicit `AutomationId` on the row (above)
over matching item Name.
