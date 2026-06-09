using FlightFinder.UiTests.Infrastructure;

namespace FlightFinder.UiTests;

/// <summary>
///     The trivial first smoke. It exists to prove the whole pipeline end to end:
///     build the app, start Appium, launch under NovaWindows, find one element.
///     Keep this one tiny.
/// </summary>
[TestFixture]
[Category("UiSmoke")]
public sealed class LaunchSmokeTest : AppiumSmokeBase
{
    protected override string LogPrefix => "launch-smoke";

    [Test]
    public void App_launches_and_search_form_is_present()
    {
        var searchButton = WaitForId("SearchButton");
        Assert.That(searchButton.Displayed, Is.True, "Search button should be visible on launch.");
    }
}
