using System.Windows;
using System.Windows.Controls;

namespace FlightFinder.App;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel = new();

    // Parameterless ctor for the XAML designer / default activation.
    public MainWindow() : this(false)
    {
    }

    public MainWindow(bool preload)
    {
        InitializeComponent();
        DataContext = _viewModel;

        if (preload)
        {
            _viewModel.Search();
        }
    }

    private void Search_Click(object sender, RoutedEventArgs e)
    {
        _viewModel.Search();
    }

    private void NavSearch_Click(object sender, RoutedEventArgs e)
    {
        SearchPage.Visibility = Visibility.Visible;
        AboutPage.Visibility = Visibility.Collapsed;
    }

    private void NavAbout_Click(object sender, RoutedEventArgs e)
    {
        SearchPage.Visibility = Visibility.Collapsed;
        AboutPage.Visibility = Visibility.Visible;
    }

    private void OpenResult_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { DataContext: FlightResult result })
        {
            _viewModel.MarkOpened(result);
        }
    }
}
