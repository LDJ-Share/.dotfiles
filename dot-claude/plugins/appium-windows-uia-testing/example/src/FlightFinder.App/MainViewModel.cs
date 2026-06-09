using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace FlightFinder.App;

/// <summary>
///     Minimal hand-rolled MVVM (no extra packages) so the demo stays focused on
///     the UI-automation surface rather than a framework.
/// </summary>
public sealed class MainViewModel : INotifyPropertyChanged
{
    private string _origin = string.Empty;
    private string _destination = string.Empty;
    private string _statusText = "Enter a route and search.";

    public string Origin
    {
        get => _origin;
        set => Set(ref _origin, value);
    }

    public string Destination
    {
        get => _destination;
        set => Set(ref _destination, value);
    }

    public string StatusText
    {
        get => _statusText;
        private set => Set(ref _statusText, value);
    }

    public ObservableCollection<FlightResult> Results { get; } = [];

    /// <summary>Populate deterministic demo results so the UI smokes are stable.</summary>
    public void Search()
    {
        Results.Clear();
        foreach (FlightResult result in SampleResults())
        {
            Results.Add(result);
        }

        StatusText = $"{Results.Count} results";
    }

    public void MarkOpened(FlightResult result)
    {
        StatusText = $"Opened {result.Route}";
    }

    private static IEnumerable<FlightResult> SampleResults()
    {
        // A real app would query a supplier with Origin/Destination. Fixed data
        // keeps the smoke tests deterministic.
        yield return new FlightResult(1, "Hub A -> Hub B", "Demo Air", "$248");
        yield return new FlightResult(2, "Hub A -> Hub C", "Sample Wings", "$291");
        yield return new FlightResult(3, "Hub A -> Hub B", "Example Jet", "$317");
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
