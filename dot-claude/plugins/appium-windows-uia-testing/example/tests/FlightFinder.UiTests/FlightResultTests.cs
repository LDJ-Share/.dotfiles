using FlightFinder.App;

namespace FlightFinder.UiTests;

/// <summary>
///     A plain unit test — no <c>[Category("UiSmoke")]</c>, does not inherit
///     <see cref="Infrastructure.AppiumSmokeBase" />, needs no Appium. It runs in
///     the FAST gate (<c>--filter "Category!=UiSmoke"</c>) so that pass has real
///     content. The whole point of category-gating is keeping tests like this one
///     away from the Appium pass (which would otherwise try, and fail, to reach
///     the server).
/// </summary>
[TestFixture]
public sealed class FlightResultTests
{
    [Test]
    public void OpenButtonId_is_unique_per_row()
    {
        var first = new FlightResult(1, "Hub A -> Hub B", "Demo Air", "$248");
        var second = new FlightResult(2, "Hub A -> Hub C", "Sample Wings", "$291");

        Assert.That(first.OpenButtonId, Is.EqualTo("OpenResult_1"));
        Assert.That(second.OpenButtonId, Is.Not.EqualTo(first.OpenButtonId));
    }

    [Test]
    public void CardSummary_includes_route_airline_and_price()
    {
        var result = new FlightResult(1, "Hub A -> Hub B", "Demo Air", "$248");

        Assert.That(result.CardSummary, Does.Contain("Hub A -> Hub B"));
        Assert.That(result.CardSummary, Does.Contain("Demo Air"));
        Assert.That(result.CardSummary, Does.Contain("$248"));
    }
}
