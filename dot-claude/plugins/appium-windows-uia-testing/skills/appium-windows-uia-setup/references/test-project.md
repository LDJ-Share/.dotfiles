# The UI test project

## `.csproj`

A Windows desktop UI test project, with Appium + a test framework. Use a
`net<ver>-windows` TFM if any fixture touches Windows-only / WPF types
(common); plain `net<ver>` is fine if not.

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0-windows</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
  </PropertyGroup>

  <ItemGroup>
    <Using Include="NUnit.Framework" />
  </ItemGroup>

  <!-- Appium drivers install into node_modules in this folder; keep it out of the build. -->
  <ItemGroup>
    <Compile Remove="node_modules/**" />
    <EmbeddedResource Remove="node_modules/**" />
    <None Remove="node_modules/**" />
    <Content Remove="node_modules/**" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Appium.WebDriver" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" />
    <PackageReference Include="NUnit" />
    <PackageReference Include="NUnit3TestAdapter" />
  </ItemGroup>
</Project>
```

Use `Appium.WebDriver` v5+ (Selenium 4 / W3C). NUnit shown; xUnit/MSTest work
too — the category gating just uses a different attribute (`[Trait]` / `[TestCategory]`).

## `package.json` (Appium server + driver)

Put this in the test project folder; pin Appium + the driver as
**devDependencies**.

```json
{
  "name": "<app>-ui-tests",
  "private": true,
  "scripts": { "appium": "appium" },
  "devDependencies": {
    "appium": "^3.0.0",
    "appium-novawindows-driver": "^1.4.0"
  }
}
```

`npm install` installs the server AND auto-discovers the local driver (it
exposes an `appium.driverName` manifest). **Do not** also run
`appium driver install novawindows` — it fails with "already installed", a
classic first-CI-run error. For WinAppDriver instead, depend on
`appium-windows-driver` and ensure `WinAppDriver.exe` is installed on the agent.

## Category-gate every Appium fixture

The fast unit gate must be able to exclude UI tests, or it will try to reach
Appium and crash. Tag every Appium fixture:

```csharp
[TestFixture]
[Category("UiSmoke")]                 // xUnit: [Trait("Category","UiSmoke")]
public sealed class LaunchSmokeTest : AppiumSmokeBase { ... }
```

```bash
dotnet test --filter "Category!=UiSmoke"   # fast gate (no Appium)
dotnet test --filter "Category=UiSmoke"    # the Appium suite (Appium must be up)
```

## Base fixture

Copy [../assets/AppiumSmokeBase.cs](../assets/AppiumSmokeBase.cs). It owns the
driver lifecycle (one app launch per fixture), verifies it attached to the
right window, exposes `AccessibilityId` helpers (`WaitForId`/`TryWaitForId`),
a nav helper with a keyboard fallback, and captures a screenshot + PageSource
on failure. Adjust:
- `ResolveExePath()` — the path to your app's built `.exe`.
- `AutomationName` — `"NovaWindows"` or `"Windows"`.
- the namespace + the window-title check string.

## First smoke test

Keep the first one trivial — it exists to prove the whole pipeline end to end:

```csharp
[TestFixture, Category("UiSmoke")]
public sealed class LaunchSmokeTest : AppiumSmokeBase
{
    [Test]
    public void App_launches_and_main_element_is_present()
    {
        var el = WaitForId("MainContentRoot");   // an AutomationId you added to the app
        Assert.That(el.Displayed, Is.True);
    }
}
```

Add an `AutomationProperties.AutomationId` to a reliable element in the app
(a `Control`/`TextBlock`/`UserControl` root — **not** a `Border`/`Grid`/`Panel`,
which get no UIA peer). See the companion `appium-windows-uia-testing` skill for
locator placement rules.

## Launch-profile parity (optional, nice for debugging)

If a fixture launches the app with special args (e.g. a preloaded-state flag),
add a matching profile to the app's `Properties/launchSettings.json` so F5 in
the IDE reproduces the test's launch conditions.
