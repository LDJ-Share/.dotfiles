using FlightFinder.UiTests.Infrastructure;
using OpenQA.Selenium.Appium;

namespace FlightFinder.UiTests;

/// <summary>
///     Drives the search form, then exercises the two counting/targeting patterns:
///     count rows by the SHARED <c>ResultCard</c> id, open one row by its UNIQUE
///     data-bound <c>OpenResult_{Id}</c> id. Both are native-UIA AccessibilityId
///     lookups — no XPath tree-walk.
/// </summary>
[TestFixture]
[Category("UiSmoke")]
public sealed class SearchSmokeTest : AppiumSmokeBase
{
    protected override string LogPrefix => "search-smoke";

    [Test]
    public void Searching_renders_result_cards_and_opening_one_updates_status()
    {
        // Use the append+backspace helper, not Clear()/Ctrl+A — see AppiumInput.
        AppiumInput.SetText(WaitForId("SearchOriginInput"), "AAA");
        AppiumInput.SetText(WaitForId("SearchDestinationInput"), "BBB");

        WaitForId("SearchButton").Click();
        Log("Clicked Search.");

        // Wait for the list to populate, then count rows by the shared leaf id.
        _ = WaitForId("ResultCard");
        var cards = Driver.FindElements(MobileBy.AccessibilityId("ResultCard"));
        Log($"Result cards: {cards.Count}");
        Assert.That(cards.Count, Is.GreaterThanOrEqualTo(1), "Expected at least one result card.");

        // Target one specific row by its unique data-bound AutomationId.
        WaitForId("OpenResult_1").Click();
        Log("Opened result 1.");

        string status = WaitForId("ResultCountText").Text;
        Assert.That(status, Does.StartWith("Opened"),
            "Opening a result should update the status text.");
    }
}
