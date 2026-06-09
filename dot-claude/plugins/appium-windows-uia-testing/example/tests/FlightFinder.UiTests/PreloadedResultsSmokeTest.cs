using FlightFinder.UiTests.Infrastructure;
using OpenQA.Selenium.Appium;

namespace FlightFinder.UiTests;

/// <summary>
///     Demonstrates the Appium <c>appArguments</c> capability + launchSettings
///     parity. Launching with <c>--preload</c> populates results at startup, so
///     this fixture asserts on them without driving the search form.
/// </summary>
[TestFixture]
[Category("UiSmoke")]
public sealed class PreloadedResultsSmokeTest : AppiumSmokeBase
{
    protected override string LogPrefix => "preloaded-smoke";

    // Returning a non-null value here adds the appArguments capability. Keep a
    // matching "(preload)" profile in launchSettings.json so F5 in the IDE
    // reproduces this launch.
    protected override string? GetAppArguments() => "--preload";

    [Test]
    public void Preloaded_results_are_present_without_searching()
    {
        _ = WaitForId("ResultCard");
        var cards = Driver.FindElements(MobileBy.AccessibilityId("ResultCard"));
        Log($"Preloaded result cards: {cards.Count}");
        Assert.That(cards.Count, Is.GreaterThanOrEqualTo(1),
            "Preloaded results should render without clicking Search.");
    }
}
