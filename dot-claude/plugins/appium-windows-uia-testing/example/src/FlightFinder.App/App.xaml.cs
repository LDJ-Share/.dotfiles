using System.Windows;

namespace FlightFinder.App;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Demo of the Appium `appArguments` capability: launching with `--preload`
        // populates results at startup so a smoke test can assert on them without
        // driving the search form. PreloadedResultsSmokeTest exercises this path,
        // and there is a matching "(preload)" profile in launchSettings.json so F5
        // in the IDE reproduces the same launch.
        bool preload = e.Args.Any(a =>
            string.Equals(a, "--preload", StringComparison.OrdinalIgnoreCase));

        new MainWindow(preload).Show();
    }
}
