// Base fixture for Appium Windows-UIA smoke tests. One app launch per fixture.
// Adjust: namespace, ResolveExePath(), AutomationName, and the window-title check.
// Drivers: "NovaWindows" (appium-novawindows-driver, no WinAppDriver) or
//          "Windows"      (appium-windows-driver / WinAppDriver.exe required).
//
// Locator rule (see the companion `appium-windows-uia-testing` skill):
//   prefer MobileBy.AccessibilityId over XPath; put AutomationIds on
//   peer-bearing elements (TextBlock/Control/UserControl), not Border/Grid/Panel.

using System.Net.Sockets;
using NUnit.Framework.Interfaces;
using OpenQA.Selenium;
using OpenQA.Selenium.Appium;
using OpenQA.Selenium.Appium.Windows;
using OpenQA.Selenium.Support.UI;

namespace YourApp.UiTests.Infrastructure;

public abstract class AppiumSmokeBase
{
    protected const string AppiumHost = "127.0.0.1";
    protected const int AppiumPort = 4723;

    protected static readonly TimeSpan ElementWait = TimeSpan.FromSeconds(15);
    protected static readonly TimeSpan ImplicitWait = TimeSpan.FromSeconds(2);

    private WindowsDriver? _driver;

    protected WindowsDriver Driver =>
        _driver ?? throw new InvalidOperationException("Driver not initialized.");

    protected virtual string LogPrefix => GetType().Name;

    // ----- lifecycle (do NOT add a second [OneTimeSetUp] in a derived fixture) -----

    [OneTimeSetUp]
    public void BaseOneTimeSetUp()
    {
        if (!IsAppiumReachable(AppiumHost, AppiumPort))
        {
            Assert.Fail($"Appium not reachable at http://{AppiumHost}:{AppiumPort} — start it first.");
            return;
        }

        string exePath = ResolveExePath();
        if (!File.Exists(exePath))
        {
            Assert.Fail($"App exe not found at {exePath} — build the app first.");
            return;
        }

        PrepareFixture();

        var options = new AppiumOptions
        {
            AutomationName = "NovaWindows",   // or "Windows" for WinAppDriver
            PlatformName = "Windows",
            App = exePath,
            DeviceName = "WindowsPC",
        };
        // NOTE: on NovaWindows, ms:waitForAppLaunch is a literal PRE-SLEEP, not a
        // max-wait — omit it; the driver already polls for the launched window.
        string? appArgs = GetAppArguments();
        if (!string.IsNullOrWhiteSpace(appArgs))
        {
            options.AddAdditionalAppiumOption("appArguments", appArgs);
        }

        try
        {
            _driver = new WindowsDriver(new Uri($"http://{AppiumHost}:{AppiumPort}"), options);
            _driver.Manage().Timeouts().ImplicitWait = ImplicitWait;
        }
        catch (Exception ex)
        {
            Log($"Session creation failed. Exe: {exePath}. {ex.Message}");
            throw;
        }

        string title = _driver.Title ?? string.Empty;
        Log($"Attached window title: '{title}'");
        if (!title.Contains("Your App", StringComparison.OrdinalIgnoreCase))   // adjust
        {
            _driver.Quit();
            _driver = null;
            Assert.Fail($"Expected the app window but attached to '{title}'.");
        }
    }

    [OneTimeTearDown]
    public void BaseOneTimeTearDown()
    {
        if (_driver is not null)
        {
            if (TestContext.CurrentContext.Result.Outcome.Status == TestStatus.Failed)
            {
                TryCaptureDiagnostics(TestContext.CurrentContext.Test.Name);
            }

            try { _driver.Quit(); } catch (Exception ex) { Log($"Quit threw: {ex.Message}"); }
        }

        CleanupFixture();
    }

    // ----- override points -----

    /// <summary>Build per-fixture artifacts (seed files, etc.) BEFORE the driver starts.</summary>
    protected virtual void PrepareFixture() { }

    /// <summary>Value for the appArguments capability, or null. If non-null, add a matching launchSettings profile.</summary>
    protected virtual string? GetAppArguments() => null;

    /// <summary>Clean up PrepareFixture artifacts AFTER teardown.</summary>
    protected virtual void CleanupFixture() { }

    // ----- helpers -----

    protected void Log(string message) => TestContext.Progress.WriteLine($"[{LogPrefix}] {message}");

    protected IWebElement WaitForId(string automationId) =>
        TryWaitForId(automationId, ElementWait)
        ?? throw new WebDriverTimeoutException($"Timed out waiting for AutomationId '{automationId}'.");

    protected IWebElement? TryWaitForId(string automationId, TimeSpan timeout)
    {
        var wait = new WebDriverWait(Driver, timeout) { PollingInterval = TimeSpan.FromMilliseconds(300) };
        wait.IgnoreExceptionTypes(typeof(NoSuchElementException), typeof(StaleElementReferenceException));
        try
        {
            return wait.Until(d =>
            {
                IWebElement el = d.FindElement(MobileBy.AccessibilityId(automationId));
                return el.Displayed ? el : null;
            });
        }
        catch (WebDriverTimeoutException) { return null; }
    }

    /// <summary>Click a nav/menu item; if the click doesn't register, fall back to keyboard Enter.</summary>
    protected void ClickNavAndWait(string navId, string targetId)
    {
        WaitForId(navId).Click();
        if (TryWaitForId(targetId, TimeSpan.FromSeconds(5)) is not null) return;
        WaitForId(navId).SendKeys(Keys.Enter);   // keyboard fallback (e.g. WPF-UI NavigationView)
        WaitForId(targetId);
    }

    protected void TryCaptureDiagnostics(string testName)
    {
        if (_driver is null) return;
        string outDir = Path.Combine(AppContext.BaseDirectory, "diagnostics");
        Directory.CreateDirectory(outDir);
        string safe = string.Join("_", testName.Split(Path.GetInvalidFileNameChars()));
        try
        {
            string png = Path.Combine(outDir, $"{safe}.png");
            _driver.GetScreenshot().SaveAsFile(png);
            TestContext.AddTestAttachment(png);
        }
        catch (Exception ex) { Log($"Screenshot failed: {ex.Message}"); }
        try
        {
            string xml = Path.Combine(outDir, $"{safe}.xml");
            File.WriteAllText(xml, _driver.PageSource ?? "<null>");
            TestContext.AddTestAttachment(xml);
        }
        catch (Exception ex) { Log($"PageSource capture failed: {ex.Message}"); }
    }

    /// <summary>Resolve the built app .exe. Adjust the parent-hops + path to your layout.</summary>
    private static string ResolveExePath()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);   // bin/Debug/net<ver>-windows
        for (int i = 0; i < 5; i++)                              // walk up to repo root
            dir = dir.Parent ?? throw new DirectoryNotFoundException("Could not reach repo root.");
        return Path.Combine(dir.FullName, "src", "YourApp", "bin", "Debug", "net10.0-windows", "YourApp.exe");
    }

    private static bool IsAppiumReachable(string host, int port)
    {
        try { using var tcp = new TcpClient(); tcp.Connect(host, port); return true; }
        catch { return false; }
    }
}
