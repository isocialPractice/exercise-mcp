# C# Weather GUI Server

A variation of [QuickstartWeatherServer](https://github.com/modelcontextprotocol/csharp-sdk/tree/main/samples/QuickstartWeatherServer) from the
[develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server#c%23),
focusing on GUI API usage.

> [!IMPORTANT]
> Don't write to stdout, or use `Console.WriteLine()`.

## Use With Claude

Build the server first (see [Build Server](#build-server)), then register it.
The tools arrive as `get_alerts`, `get_forecast`, `render_weather`, and
`draw_weather_svg` under the `weather-server-gui` name.

**Claude Code (CLI or VS Code extension)**

Claude Code reads its own MCP config, not the Claude Desktop file:

```batch
claude mcp add --scope user weather-server-gui -- dotnet run --project "D:\Users\name\path\to\weather-server" --no-build
```

Start a new session, then run `/mcp` to confirm the server connected.

**Claude Desktop**

Add the entry from [Add Server](#add-server) to the `mcpServers` object in
`%APPDATA%\Claude\claude_desktop_config.json`, then fully quit Claude Desktop
from its tray icon and reopen it.

### Example Claude Code Prompt

From a reopository workspace:

```text
Call weather-server-gui at "path/to/server"
render_weather with temperature "hot", precipitation "stormy",
the current time, then carry out the directives it returns - create the
`local-weather-style/STYLE.md` and local-weather branch, and restyle the app
accordingly.
```

- Tested on [ccal](https://github.com/jhauga/ccal/tree/local-weather)

## Quick Snippets

```
# output
// log to stderr or files, no Console.WriteLine()

# project setup
dotnet add package ModelContextProtocol --prerelease
dotnet add package Microsoft.Extensions.Hosting

# build
builder.Services.AddMcpServer()
    .WithStdioServerTransport()
    .WithToolsFromAssembly();
```

<details>

<summary>Show Details</summary>

**Code**

```csharp
// Outputting
///////////////////////////////////////////////////////////////////////////////
// instead of Console.WriteLine() use:
Console.Error.WriteLine("Processing:"); // writes to stderr

// Minimum Server
///////////////////////////////////////////////////////////////////////////////
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using ModelContextProtocol;

var builder = Host.CreateEmptyApplicationBuilder(settings: null);

builder.Services.AddMcpServer()
    .WithStdioServerTransport()
    .WithToolsFromAssembly();

var app = builder.Build();

await app.RunAsync();
```

**Commands**

```batch
:: Project Setup
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
mkdir <server> & cd <server>
dotnet new console
dotnet add package ModelContextProtocol --prerelease
dotnet add package Microsoft.Extensions.Hosting
```

</details>

## Setup Server Environment

1. Use `dotnet` 8 or higher

```batch
dotnet --version
```

2. Project setup

<CodeGroup>

```bash macOS/Linux
# Create a new directory for our project
mkdir weather
cd weather
# Initialize a new C# project
dotnet new console
```

```batch Windows
:: Create directory
mkdir weather-server
cd weather-server

:: Initialize C# project
dotnet new console

:: Dependency installation
dotnet add package ModelContextProtocol --prerelease
dotnet add package Microsoft.Extensions.Hosting

:: Server files
mkdir Tools Utils Gui
```

</CodeGroup>

## C# MCP Server

The server created in this exercise is a variation of the below files.
<!--START_CSPROJ-->
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <RootNamespace>WeatherServer</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="ModelContextProtocol" Version="0.3.0-preview.3" />
    <PackageReference Include="Microsoft.Extensions.Hosting" Version="8.0.1" />
  </ItemGroup>

</Project>
```
<!--END_CSPROJ-->
### `Program.cs`
<!--START_SERVER-->
```csharp
// Import dependencies
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using ModelContextProtocol;
using System.Net.Http.Headers;

var builder = Host.CreateEmptyApplicationBuilder(settings: null);

// WithToolsFromAssembly registers every [McpServerToolType] class, so the
// weather tools and the gui tools load without being named here.
builder.Services.AddMcpServer()
    .WithStdioServerTransport()
    .WithToolsFromAssembly();

builder.Services.AddSingleton(_ =>
{
    var client = new HttpClient() { BaseAddress = new Uri("https://api.weather.gov") };
    client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("weather-app", "1.0"));
    client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/geo+json"));
    return client;
});

var app = builder.Build();

await app.RunAsync();
```
<!--END_SERVER-->
### `Tools/WeatherTools.cs`
<!--START_TOOLS-WEATHER-->
```csharp
// Import dependencies
using ModelContextProtocol.Server;
using System.ComponentModel;
using System.Globalization;
using System.Text.Json;

using WeatherServer.Gui;
using WeatherServer.Utils;

namespace WeatherServer.Tools;

[McpServerToolType]
public static class WeatherTools
{
    // Local time format the GUI render tool reads.
    private const string LocalTimeFormat = "HH:mm:ss";

    private static string LocalTime() =>
        DateTime.Now.ToString(LocalTimeFormat, CultureInfo.InvariantCulture);

    [McpServerTool(Name = "get_alerts"), Description("Get weather alerts for a US state.")]
    public static async Task<string> GetAlerts(
        HttpClient client,
        [Description("Two-letter US state code (e.g. CA, NY)")] string state)
    {
        using var jsonDocument = await client.ReadJsonDocumentAsync(
            $"/alerts/active/area/{state.ToUpperInvariant()}");
        if (jsonDocument is null ||
            !jsonDocument.RootElement.TryGetProperty("features", out var features))
        {
            return "Unable to fetch alert or alert not found.";
        }

        var alerts = features.EnumerateArray().ToList();
        if (alerts.Count == 0)
        {
            return "No active alert for the state.";
        }

        return string.Join("\n---\n", alerts.Select(FormatAlert.Format));
    }

    [McpServerTool(Name = "get_forecast"), Description("Get weather forecast for a location.")]
    public static async Task<string> GetForecast(
        HttpClient client,
        [Description("Latitude of the location")] double latitude,
        [Description("Longitude of the location")] double longitude)
    {
        // forecast grid endpoint
        var pointsUrl = string.Create(CultureInfo.InvariantCulture, $"/points/{latitude},{longitude}");
        using var pointsDocument = await client.ReadJsonDocumentAsync(pointsUrl);
        if (pointsDocument is null)
        {
            return "Unable to fetch forecast data for this location.";
        }

        // Get the forecast URL from points response
        var forecastUrl = pointsDocument.RootElement
            .GetProperty("properties").GetProperty("forecast").GetString();
        if (forecastUrl is null)
        {
            return "Unable to fetch detailed forecast for this location.";
        }

        using var forecastDocument = await client.ReadJsonDocumentAsync(forecastUrl);
        if (forecastDocument is null)
        {
            return "Unable to fetch detailed forecast for this location.";
        }

        var periods = forecastDocument.RootElement
            .GetProperty("properties").GetProperty("periods")
            .EnumerateArray().ToList();
        if (periods.Count == 0)
        {
            return "No forecast periods available for this location.";
        }

        var forecasts = periods.Take(5).Select(period => $"""

            {period.GetProperty("name").GetString()}:
            Temperature: {period.GetProperty("temperature").GetInt32()}°{period.GetProperty("temperatureUnit").GetString()}
            Wind: {period.GetProperty("windSpeed").GetString()} {period.GetProperty("windDirection").GetString()}
            Forecast: {period.GetProperty("detailedForecast").GetString()}
            """);

        var currentForecast = string.Join("\n---\n", forecasts);
        // The first period is the current one, so the GUI styles from it.
        var renderData = CategorizeLocalWeather.Categorize(periods[0]);
        var renderDirectives = GuiRenderWeather.Render(renderData, LocalTime());

        return $"""
            {currentForecast}
            ---
            Local Weather: {CategorizeLocalWeather.FormatLocalWeather(renderData)}
            {renderDirectives}
            """;
    }
}
```
<!--END_TOOLS-WEATHER-->
### `Utils/HttpClientExt.cs`
<!--START_UTILS-MAKE-NWS-REQUEST-->
```csharp
// Import dependencies
using System.Text.Json;

namespace WeatherServer.Utils;

internal static class HttpClientExt
{
    /// <summary>Make a request to the NWS API with proper error handling.</summary>
    public static async Task<JsonDocument?> ReadJsonDocumentAsync(this HttpClient client, string requestUri)
    {
        try
        {
            using var response = await client.GetAsync(requestUri);
            response.EnsureSuccessStatusCode();
            return await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync());
        }
        catch (Exception)
        {
            return null;
        }
    }
}
```
<!--END_UTILS-MAKE-NWS-REQUEST-->
### `Utils/FormatAlert.cs`
<!--START_UTILS-FORMAT-ALERT-->
```csharp
// Import dependencies
using System.Text.Json;

namespace WeatherServer.Utils;

internal static class FormatAlert
{
    /// <summary>Format an alert feature into a readable string.</summary>
    public static string Format(JsonElement feature)
    {
        var props = feature.GetProperty("properties");

        string Read(string key, string fallback) =>
            props.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String
                ? value.GetString() ?? fallback
                : fallback;

        return $"""

            Event: {Read("event", "Unknown")}
            Area: {Read("areaDesc", "Unknown")}
            Severity: {Read("severity", "Unknown")}
            Description: {Read("description", "No description available")}
            Instruction: {Read("instruction", "No specific instructions provided")}
            """;
    }
}
```
<!--END_UTILS-FORMAT-ALERT-->
### `Utils/CategorizeLocalWeather.cs`
<!--START_CATEGORIZE-LOCAL-WEATHER-->
```csharp
// Import dependencies
using System.Globalization;
using System.Text.Json;

namespace WeatherServer.Utils;

/// <summary>The two styling values the GUI renders from.</summary>
public sealed record LocalWeather(string Temperature, string Precipitation);

public static class CategorizeLocalWeather
{
    // Constant variables
    private const double HotThresholdF = 80.0;
    private const double ColdThresholdF = 32.0;
    private static readonly string[] StormTerms = ["thunder", "storm", "squall", "hail", "blizzard", "torrential"];
    private static readonly string[] RainTerms = ["rain", "shower", "drizzle", "snow", "sleet", "freezing", "precipitation"];
    private static readonly string[] CloudTerms = ["cloud", "overcast", "fog", "haze", "mist"];
    private static readonly string[] SevereLevels = ["high", "severe", "extreme"];

    // NWS forecast periods and alert properties describe the same conditions
    // under different key names, so each lookup below accepts either shape.
    private static readonly string[] TemperatureKeys = ["temperature", "temp"];
    private static readonly string[] UnitKeys = ["temperatureUnit", "unit"];
    private static readonly string[] ConditionKeys = ["detailedForecast", "shortForecast", "forecast", "event", "description"];
    private static readonly string[] SeverityKeys = ["severity"];

    /// <summary>Return the first populated value among keys, matched without case.</summary>
    private static string Lookup(JsonElement forecast, string[] keys, string fallback = "")
    {
        foreach (var key in keys)
        {
            foreach (var property in forecast.EnumerateObject())
            {
                if (!string.Equals(property.Name, key, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }
                var text = property.Value.ValueKind switch
                {
                    JsonValueKind.String => property.Value.GetString(),
                    JsonValueKind.Number => property.Value.GetRawText(),
                    _ => null,
                };
                if (!string.IsNullOrEmpty(text))
                {
                    return text;
                }
            }
        }
        return fallback;
    }

    /// <summary>Join every populated value among keys into one searchable string.</summary>
    private static string Collect(JsonElement forecast, string[] keys)
    {
        var found = keys
            .Select(key => Lookup(forecast, [key]))
            .Where(value => !string.IsNullOrEmpty(value));
        return string.Join(" ", found);
    }

    /// <summary>Convert a reported temperature to Fahrenheit, or null when unusable.</summary>
    private static double? ToFahrenheit(string temperature, string unit)
    {
        if (!double.TryParse(temperature, NumberStyles.Float, CultureInfo.InvariantCulture, out var degrees))
        {
            return null;
        }

        if (unit.Trim().StartsWith("C", StringComparison.OrdinalIgnoreCase))
        {
            return degrees * 9.0 / 5.0 + 32.0;
        }
        return degrees;
    }

    /// <summary>Bucket the reported temperature into hot, cold, or medium.</summary>
    private static string CategorizeTemperature(JsonElement forecast)
    {
        var degrees = ToFahrenheit(
            Lookup(forecast, TemperatureKeys),
            Lookup(forecast, UnitKeys, "F"));

        if (degrees is null)
        {
            return "medium";
        }
        if (degrees >= HotThresholdF)
        {
            return "hot";
        }
        if (degrees < ColdThresholdF)
        {
            return "cold";
        }
        return "medium";
    }

    /// <summary>Bucket the reported conditions into stormy, cloudy, or sunny.</summary>
    private static string CategorizePrecipitation(JsonElement forecast)
    {
        var conditions = Collect(forecast, ConditionKeys).ToLowerInvariant();
        var severity = Lookup(forecast, SeverityKeys).ToLowerInvariant();
        var isSevere = SevereLevels.Contains(severity);

        if (StormTerms.Any(conditions.Contains))
        {
            return "stormy";
        }
        if (RainTerms.Any(conditions.Contains))
        {
            return isSevere ? "stormy" : "cloudy";
        }
        if (CloudTerms.Any(conditions.Contains))
        {
            return "cloudy";
        }
        return "sunny";
    }

    /// <summary>
    /// Reduce a forecast period to the two styling values the GUI renders from:
    /// Temperature as one of hot, medium, cold, and Precipitation as one of
    /// stormy, cloudy, sunny.
    /// </summary>
    public static LocalWeather Categorize(JsonElement forecast) =>
        new(CategorizeTemperature(forecast), CategorizePrecipitation(forecast));

    /// <summary>Format categorized weather as a single readable line.</summary>
    public static string FormatLocalWeather(LocalWeather localWeather) =>
        $"Temperature: {localWeather.Temperature}, Precipitation: {localWeather.Precipitation}";
}
```
<!--END_CATEGORIZE-LOCAL-WEATHER-->
### `Gui/GuiRenderWeather.cs`
<!--START_GUI-RENDER-WEATHER-->
```csharp
// Import dependencies
using ModelContextProtocol.Server;
using System.ComponentModel;
using System.Globalization;

using WeatherServer.Utils;

namespace WeatherServer.Gui;

[McpServerToolType]
public static class GuiRenderWeather
{
    // Constant variables
    internal const int DayStartHour = 8; // 8AM
    internal const int DayEndHour = 20;  // 8PM
    private static readonly string[] TimeFormats = ["HH:mm:ss", "HH:mm", "hh:mm:ss tt", "hh:mm tt"];

    /// <summary>Return the hour of day for a time given as text, or now when unparseable.</summary>
    internal static int HourOfDay(string currentTime)
    {
        var text = currentTime.Trim();
        foreach (var timeFormat in TimeFormats)
        {
            if (DateTime.TryParseExact(text, timeFormat, CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out var parsed))
            {
                return parsed.Hour;
            }
        }

        // Unparseable input still has to render something, so fall back to now.
        return DateTime.Now.Hour;
    }

    [McpServerTool(Name = "render_weather"), Description("""
        Render current GUI application based on local weather.
           A. If a file does not exist in repo that is compatible with this
              application, like "local-weather-style/STYLE.md", then:
               1. Determine application architecture
               2. Read styling
                  - Analyze current styling
               3. Write to "local-weather-style/STYLE.md" how to update GUI apps
                  styling next time this API is called
               4. Recurse to part "B"
           B. Else if the application is a `git` repo:
               1. If branch like "local-weather" exist, then:
                  - run: `git checkout local-weather`
                  - else run: `git checkout -b local-weather`
               2. Read "local-weather-style/STYLE.md"
               3. Update style according to arguments, and launch GUI
           C. Else:
              1. Do not make style changes
                - Do nothing, and exit

           The repoPath argument, when provided, names the repository of the
           GUI application parts A and B apply to.
        """)]
    public static string RenderWeather(
        [Description("Temperature style, one of hot, medium, cold")] string temperature,
        [Description("Precipitation style, one of stormy, cloudy, sunny")] string precipitation,
        [Description("Local time of day")] string currentTime,
        [Description("Repository of the GUI application to style")] string? repoPath = null) =>
        Render(new LocalWeather(temperature, precipitation), currentTime, repoPath);

    /// <summary>Render current GUI application based on local weather.</summary>
    public static string Render(LocalWeather localWeather, string currentTime, string? repoPath = null)
    {
        var hour = HourOfDay(currentTime);
        var dayOrNight = hour >= DayStartHour && hour < DayEndHour ? "day" : "night";
        var temperatureStyle = string.IsNullOrEmpty(localWeather.Temperature) ? "medium" : localWeather.Temperature;
        var precipeStyle = string.IsNullOrEmpty(localWeather.Precipitation) ? "sunny" : localWeather.Precipitation;
        var repoTarget = string.IsNullOrEmpty(repoPath) ? "" : $"- Apply Styling To Repo: {repoPath}\n";

        return $"""

            {repoTarget}- Render Background: {dayOrNight}
            - Render Tone: {temperatureStyle}
            - Precipitation Use: Set per {precipeStyle}
            - Copy Paste Assets Server Assets:
               - Determine GUI Application Context:
                 - if game-like, then use assets, else do not use assets;
                 - if game-like:
                   - if "{precipeStyle}" is "cloudy" or "stormy", then use cloud.svg
                     - if "{temperatureStyle}" is "cold", then use snow.svg, else use rain.svg
                   - else do not use cloud.svg, and style sky blue
                 - if "{dayOrNight}" is "day" use sun.svg, else use moon.svg

            """;
    }
}
```
<!--END_GUI-RENDER-WEATHER-->
### `Gui/GuiDrawWeather.cs`
<!--START_GUI-DRAW-WEATHER-->
```csharp
// Import dependencies
using ModelContextProtocol.Server;
using System.ComponentModel;

using WeatherServer.Utils;

namespace WeatherServer.Gui;

[McpServerToolType]
public static class GuiDrawWeather
{
    // Constant variables
    // The build output runs from bin/<Config>/<tfm>/, so walk candidates back
    // to the project folder where assets/ ships.
    private static readonly string AssetsDir = FindAssetsDir();
    private const string DayAsset = "sun.svg";
    private const string NightAsset = "moon.svg";
    private const string CloudAsset = "cloud.svg";
    private const string RainAsset = "rain.svg";
    private const string SnowAsset = "snow.svg";
    private static readonly string[] OvercastStyles = ["cloudy", "stormy"];

    // Stand-in artwork for an asset the server does not ship, so the GUI always
    // has something to draw. Deliberately plain, since it only holds the place.
    private const string MissingSvg =
        "<svg id=\"{0}\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 360 360\">" +
        "<circle cx=\"180\" cy=\"180\" r=\"160\" fill=\"#d2d2d2\" stroke=\"#000\" stroke-width=\"8\"/>" +
        "<text x=\"180\" y=\"196\" fill=\"#000\" font-family=\"sans-serif\" font-size=\"44\"" +
        " text-anchor=\"middle\">{1}</text>" +
        "</svg>";

    private static string FindAssetsDir()
    {
        var current = AppContext.BaseDirectory;
        for (var i = 0; i < 4 && current is not null; i++)
        {
            var candidate = Path.Combine(current, "assets");
            if (Directory.Exists(candidate))
            {
                return candidate;
            }
            current = Path.GetDirectoryName(current);
        }
        return Path.Combine(AppContext.BaseDirectory, "assets");
    }

    /// <summary>Return the assets the current weather calls for, in draw order.</summary>
    private static List<string> DrawSet(LocalWeather localWeather, string dayOrNight)
    {
        var temperatureStyle = string.IsNullOrEmpty(localWeather.Temperature) ? "medium" : localWeather.Temperature;
        var precipeStyle = string.IsNullOrEmpty(localWeather.Precipitation) ? "sunny" : localWeather.Precipitation;

        var drawSet = new List<string> { dayOrNight == "day" ? DayAsset : NightAsset };
        if (OvercastStyles.Contains(precipeStyle))
        {
            drawSet.Add(CloudAsset);
            drawSet.Add(temperatureStyle == "cold" ? SnowAsset : RainAsset);
        }
        return drawSet;
    }

    /// <summary>Draw the stand-in markup for an asset the server is missing.</summary>
    private static string ClicheSvg(string asset)
    {
        var name = Path.GetFileNameWithoutExtension(asset);
        return string.Format(MissingSvg, name, name.ToUpperInvariant());
    }

    [McpServerTool(Name = "draw_weather_svg"), Description("""
        Draw the SVG set for the current weather, as directives for the GUI app.

        Each asset the server ships is drawn from disk. Any asset it does not
        ship is drawn as a plain stand-in instead, so the draw set is never
        short. When the server ships no asset at all, the directives ask for the
        artwork to be generated rather than copied.
        """)]
    public static string DrawWeatherSvg(
        [Description("Temperature style, one of hot, medium, cold")] string temperature,
        [Description("Precipitation style, one of stormy, cloudy, sunny")] string precipitation,
        [Description("Local time of day")] string currentTime) =>
        Draw(new LocalWeather(temperature, precipitation), currentTime);

    /// <summary>Draw the SVG set for the current weather, as directives for the GUI app.</summary>
    public static string Draw(LocalWeather localWeather, string currentTime)
    {
        var hour = GuiRenderWeather.HourOfDay(currentTime);
        var dayOrNight = hour >= GuiRenderWeather.DayStartHour && hour < GuiRenderWeather.DayEndHour
            ? "day"
            : "night";
        var drawSet = DrawSet(localWeather, dayOrNight);

        var available = new List<string>();
        var missing = new List<string>();
        foreach (var asset in drawSet)
        {
            var path = Path.Combine(AssetsDir, asset);
            if (File.Exists(path))
            {
                available.Add($"   - {asset}: {path}");
            }
            else
            {
                missing.Add($"   - {asset}:\n     {ClicheSvg(asset)}");
            }
        }

        // Nothing on disk to draw from, so the artwork has to be generated.
        if (available.Count == 0)
        {
            return $"""

                - Draw SVG Set: {string.Join(", ", drawSet)}
                - Generate SVG:
                   - The server ships no asset for the current weather, so generate one SVG per
                     name in the draw set
                   - Match each one to the styling the GUI application already uses
                   - Keep every viewBox square and the markup self contained, with no external
                     references

                """;
        }

        var serverPromptOutput = new List<string> { $"- Draw SVG Set: {string.Join(", ", drawSet)}" };
        serverPromptOutput.Add("- Draw From Server Assets:");
        serverPromptOutput.AddRange(available);
        if (missing.Count > 0)
        {
            serverPromptOutput.Add("- Draw Stand-In, Server Ships No Asset:");
            serverPromptOutput.AddRange(missing);
        }
        serverPromptOutput.AddRange(
        [
            "- Add SVG Tool:",
            "   - For each language the GUI application is written in:",
            "     - Read the application and find the style pattern it already uses",
            "     - Add one lightweight SVG helper built on that style pattern:",
            "       - if the application groups behavior in classes, add a method",
            "       - else add a function",
            "     - The helper takes a name from the draw set and returns its markup",
            "   - Add no dependency, the helper stays lightweight",
        ]);

        return "\n" + string.Join("\n", serverPromptOutput) + "\n";
    }
}
```
<!--END_GUI-DRAW-WEATHER-->

## Build Server

The project setup is deliberately different. Instead of one `Program.cs` file,
this server will have:

- Entry: `Program.cs`
- Tools: `Tools/`
  - `WeatherTools.cs`
- Helper functions: `Utils/`
  - `HttpClientExt.cs`
  - `FormatAlert.cs`
  - `CategorizeLocalWeather.cs`
    - Summary: for GUI instance of server, so weather will change display according to:
      - Hot, Medium, or Cold
        - Cold: **temp. < 32°F(0°C)**
        - Medium: **temp. > `cold` && temp. < 80°F(26.67°C)**
        - Hot: **temp. >= 80°F(26.67°C)**
        - Each determines effect for `["stormy", "cloudy", "sunny"]`
      - Stormy, Cloudy, or Sunny
        - If stormy or cloudy, then:
          - If stormy, then more precipitation; else less precipitation
          - If cold, then snow; else rain
          - If medium or hot, then:
            - Medium: more gray toned
            - Hot: more dark toned
- GUI rendering: `Gui/`
  - `GuiRenderWeather.cs`
  - `GuiDrawWeather.cs`
- GUI Graphics: `assets/`
  - `cloud.svg`
  - `sun.svg`
  - `moon.svg`
  - `rain.svg`
  - `snow.svg`

Run with `dotnet run` from the project folder.

## Add Server

**Claude Desktop**

<CodeGroup>

```json macOS/Linux
"weather-server-gui": {
  "command": "dotnet",
  "args": ["run", "--project", "/PATH/TO/weather-server", "--no-build"]
}
```

```json Windows
    "weather-server-gui": {
      "command": "dotnet",
      "args": [
        "run",
        "--project",
        "D:\\Users\\name\\path\\to\\weather-server",
        "--no-build"
      ]
    }
```

</CodeGroup>

## Additionally

- [csharp-sdk](https://github.com/modelcontextprotocol/csharp-sdk)
