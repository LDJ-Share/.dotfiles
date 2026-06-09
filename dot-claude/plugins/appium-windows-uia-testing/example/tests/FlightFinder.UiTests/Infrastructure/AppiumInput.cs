using OpenQA.Selenium;

namespace FlightFinder.UiTests.Infrastructure;

/// <summary>
///     WPF TextBox input helper.
///     <para>
///         On windows-latest CI, NovaWindowsDriver does NOT reliably fire WPF's
///         TwoWay binding through <c>Clear()</c> or a Ctrl+A + Delete sequence —
///         the bound property silently keeps its old value. Setting text by
///         appending and then backspacing over any prior value drives each key
///         through WPF's normal input pipeline, so <c>PropertyChanged</c> fires
///         and the binding updates. This is the reliable cross-driver pattern.
///     </para>
/// </summary>
public static class AppiumInput
{
    public static void SetText(IWebElement textBox, string value)
    {
        textBox.Click();

        string existing = textBox.Text ?? string.Empty;
        if (existing.Length > 0)
        {
            textBox.SendKeys(string.Concat(Enumerable.Repeat(Keys.Backspace, existing.Length)));
        }

        textBox.SendKeys(value);
    }
}
