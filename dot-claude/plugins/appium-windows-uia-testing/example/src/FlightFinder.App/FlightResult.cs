namespace FlightFinder.App;

/// <summary>A single search result row. Deliberately tiny — this is a UI-automation
/// demo, not a real flight engine.</summary>
public sealed class FlightResult
{
    public FlightResult(int id, string route, string airline, string price)
    {
        Id = id;
        Route = route;
        Airline = airline;
        Price = price;
    }

    public int Id { get; }
    public string Route { get; }
    public string Airline { get; }
    public string Price { get; }

    /// <summary>What the card shows. Bound to the per-row counting leaf's text.</summary>
    public string CardSummary => $"{Route}  ·  {Airline}  ·  {Price}";

    /// <summary>
    ///     A per-row UNIQUE AutomationId, so a test can target one specific row by
    ///     its data (e.g. <c>AccessibilityId("OpenResult_1")</c>) instead of walking
    ///     the tree with XPath. See the companion `appium-windows-uia-testing` skill.
    /// </summary>
    public string OpenButtonId => $"OpenResult_{Id}";
}
