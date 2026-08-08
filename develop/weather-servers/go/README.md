# Go Weather GUI Server

A variation of [weather-server-go](https://github.com/modelcontextprotocol/quickstart-resources/tree/main/weather-server-go) from the
[develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server#go),
focusing on GUI API usage.

> [!IMPORTANT]
> Don't write to stdout, or use `fmt.Println()`.

## Use With Claude

Build the server first (see [Build Server](#build-server)), then register it.
The tools arrive as `get_alerts`, `get_forecast`, `render_weather`, and
`draw_weather_svg` under the `weather-server-gui` name.

**Claude Code (CLI or VS Code extension)**

Claude Code reads its own MCP config, not the Claude Desktop file:

```batch
claude mcp add --scope user weather-server-gui -- "D:\Users\name\path\to\weather-server\weather-server.exe"
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

- Tested on [vscode-flight-map](https://github.com/isocialPractice/vscode-flight-map/tree/local-weather)

## Quick Snippets

```
# output
log.Println("txt") // defaults to stderr, no fmt.Println()

# project setup
go get github.com/modelcontextprotocol/go-sdk/mcp

# build
server := mcp.NewServer(&mcp.Implementation{Name: "<server>", Version: "1.0.0"}, nil)
```

<details>

<summary>Show Details</summary>

**Code**

```go
// Outputting
///////////////////////////////////////////////////////////////////////////////
// instead of fmt.Println() use:
log.Println("Processing:")            // defaults to stderr
fmt.Fprintln(os.Stderr, "Processing:") // stderr explicitly

// Minimum Server
///////////////////////////////////////////////////////////////////////////////
package main

import (
	"context"
	"log"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

func main() {
	server := mcp.NewServer(&mcp.Implementation{
		Name:    "Demo",
		Version: "1.0.0",
	}, nil)

	if err := server.Run(context.Background(), &mcp.StdioTransport{}); err != nil {
		log.Fatal(err)
	}
}
```

**Commands**

```batch
:: Project Setup
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
md <server> & cd <server>
go mod init <server>
go get <dependencies>
new-item main.go
```

</details>

## Setup Server Environment

1. Use `go` 1.24 or higher

```batch
go version
```

2. Project setup

<CodeGroup>

```bash macOS/Linux
# Create a new directory for our project
mkdir weather
cd weather

# Initialize Go module
go mod init weather

# Install dependencies
go get github.com/modelcontextprotocol/go-sdk/mcp

# Create our server file
touch main.go
```

```batch Windows
:: Create directory
md weather-server
cd weather-server

:: Initialize Go module
go mod init weather-server

:: Dependency installation
go get github.com/modelcontextprotocol/go-sdk/mcp

:: Server files
md utils gui
new-item main.go
```

</CodeGroup>

## Go MCP Server

The server created in this exercise is a variation of the below files.
`go get` fills in the `require` lines when the dependency installs.
<!--START_GOMOD-->
```go
module weather-server

go 1.24
```
<!--END_GOMOD-->
### `main.go`
<!--START_SERVER-->
```go
// Package main is the MCP weather server entry point.
package main

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/modelcontextprotocol/go-sdk/mcp"

	"weather-server/gui"
	"weather-server/utils"
)

// Constant variables
const (
	NWSAPIBase      = "https://api.weather.gov"
	LocalTimeFormat = "15:04:05"
)

type PointsResponse struct {
	Properties struct {
		Forecast string `json:"forecast"`
	} `json:"properties"`
}

type ForecastResponse struct {
	Properties struct {
		Periods []utils.ForecastPeriod `json:"periods"`
	} `json:"properties"`
}

type AlertsResponse struct {
	Features []utils.AlertFeature `json:"features"`
}

type ForecastInput struct {
	Latitude  float64 `json:"latitude" jsonschema:"Latitude of the location"`
	Longitude float64 `json:"longitude" jsonschema:"Longitude of the location"`
}

type AlertsInput struct {
	State string `json:"state" jsonschema:"Two-letter US state code (e.g. CA, NY)"`
}

// GuiInput carries the categorized weather and the local time of day the GUI
// tools style from.
type GuiInput struct {
	Temperature   string `json:"temperature" jsonschema:"Temperature style, one of hot, medium, cold"`
	Precipitation string `json:"precipitation" jsonschema:"Precipitation style, one of stormy, cloudy, sunny"`
	CurrentTime   string `json:"currentTime" jsonschema:"Local time of day"`
	RepoPath      string `json:"repoPath,omitempty" jsonschema:"Repository of the GUI application to style"`
}

// localTime returns the current local time, formatted for the GUI render tool.
func localTime() string {
	return time.Now().Format(LocalTimeFormat)
}

func textResult(text string) *mcp.CallToolResult {
	return &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: text},
		},
	}
}

func getAlerts(ctx context.Context, req *mcp.CallToolRequest, input AlertsInput) (
	*mcp.CallToolResult, any, error,
) {
	stateCode := strings.ToUpper(input.State)
	alertsURL := fmt.Sprintf("%s/alerts/active/area/%s", NWSAPIBase, stateCode)

	alertsData, err := utils.MakeNWSRequest[AlertsResponse](ctx, alertsURL)
	if err != nil {
		return textResult("Unable to fetch alert or alert not found."), nil, nil
	}

	if len(alertsData.Features) == 0 {
		return textResult("No active alert for the state."), nil, nil
	}

	var alerts []string
	for _, feature := range alertsData.Features {
		alerts = append(alerts, utils.FormatAlert(feature))
	}

	return textResult(strings.Join(alerts, "\n---\n")), nil, nil
}

func getForecast(ctx context.Context, req *mcp.CallToolRequest, input ForecastInput) (
	*mcp.CallToolResult, any, error,
) {
	// forecast grid endpoint
	pointsURL := fmt.Sprintf("%s/points/%f,%f", NWSAPIBase, input.Latitude, input.Longitude)
	pointsData, err := utils.MakeNWSRequest[PointsResponse](ctx, pointsURL)
	if err != nil {
		return textResult("Unable to fetch forecast data for this location."), nil, nil
	}

	// Get the forecast URL from points response
	forecastURL := pointsData.Properties.Forecast
	if forecastURL == "" {
		return textResult("Unable to fetch detailed forecast for this location."), nil, nil
	}

	forecastData, err := utils.MakeNWSRequest[ForecastResponse](ctx, forecastURL)
	if err != nil {
		return textResult("Unable to fetch detailed forecast for this location."), nil, nil
	}

	periods := forecastData.Properties.Periods
	if len(periods) == 0 {
		return textResult("No forecast periods available for this location."), nil, nil
	}

	var forecasts []string
	for i := range min(5, len(periods)) { // next 5 periods
		period := periods[i]
		forecasts = append(forecasts, fmt.Sprintf(`
%s:
Temperature: %d°%s
Wind: %s %s
Forecast: %s
`, period.Name, period.Temperature, period.TemperatureUnit,
			period.WindSpeed, period.WindDirection, period.DetailedForecast))
	}

	currentForecast := strings.Join(forecasts, "\n---\n")
	// The first period is the current one, so the GUI styles from it.
	renderData := utils.CategorizeLocalWeather(periods[0])
	renderDirectives := gui.RenderWeather(renderData, localTime(), "")

	result := fmt.Sprintf(`%s
---
Local Weather: %s
%s`, currentForecast, utils.FormatLocalWeather(renderData), renderDirectives)

	return textResult(result), nil, nil
}

func renderWeather(ctx context.Context, req *mcp.CallToolRequest, input GuiInput) (
	*mcp.CallToolResult, any, error,
) {
	local := utils.LocalWeather{
		Temperature:   input.Temperature,
		Precipitation: input.Precipitation,
	}
	return textResult(gui.RenderWeather(local, input.CurrentTime, input.RepoPath)), nil, nil
}

func drawWeatherSvg(ctx context.Context, req *mcp.CallToolRequest, input GuiInput) (
	*mcp.CallToolResult, any, error,
) {
	local := utils.LocalWeather{
		Temperature:   input.Temperature,
		Precipitation: input.Precipitation,
	}
	return textResult(gui.DrawWeatherSvg(local, input.CurrentTime)), nil, nil
}

func main() {
	// Create MCP server
	server := mcp.NewServer(&mcp.Implementation{
		Name:    "weather-server",
		Version: "0.1.0",
	}, nil)

	// gui.RenderWeather and gui.DrawWeatherSvg are defined in gui/ so that
	// package stays free of the server instance, so expose them as tools here.
	mcp.AddTool(server, &mcp.Tool{
		Name:        "render_weather",
		Description: gui.RenderWeatherDescription,
	}, renderWeather)

	mcp.AddTool(server, &mcp.Tool{
		Name:        "draw_weather_svg",
		Description: gui.DrawWeatherSvgDescription,
	}, drawWeatherSvg)

	mcp.AddTool(server, &mcp.Tool{
		Name:        "get_alerts",
		Description: "Get weather alerts for a US state",
	}, getAlerts)

	mcp.AddTool(server, &mcp.Tool{
		Name:        "get_forecast",
		Description: "Get weather forecast for a location",
	}, getForecast)

	// Run server on stdio transport
	if err := server.Run(context.Background(), &mcp.StdioTransport{}); err != nil {
		log.Fatal(err)
	}
}
```
<!--END_SERVER-->
### `utils/make_nws_request.go`
<!--START_UTILS-MAKE-NWS-REQUEST-->
```go
// Package utils holds the NWS request, formatting, and categorizing helpers.
package utils

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

// Constant variables
const UserAgent = "weather-app/1.0"

// MakeNWSRequest makes a request to the NWS API with proper error handling.
func MakeNWSRequest[T any](ctx context.Context, url string) (*T, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", UserAgent)
	req.Header.Set("Accept", "application/geo+json")

	client := http.DefaultClient
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to make request to %s: %w", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("HTTP error %d: %s", resp.StatusCode, string(body))
	}

	var result T
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &result, nil
}
```
<!--END_UTILS-MAKE-NWS-REQUEST-->
### `utils/format_alert.go`
<!--START_UTILS-FORMAT-ALERT-->
```go
package utils

import (
	"cmp"
	"fmt"
)

// AlertFeature is one alert entry of a NWS alerts response.
type AlertFeature struct {
	Properties AlertProperties `json:"properties"`
}

// AlertProperties carries the alert fields the formatter reads.
type AlertProperties struct {
	Event       string `json:"event"`
	AreaDesc    string `json:"areaDesc"`
	Severity    string `json:"severity"`
	Description string `json:"description"`
	Instruction string `json:"instruction"`
}

// FormatAlert formats an alert feature into a readable string.
func FormatAlert(alert AlertFeature) string {
	props := alert.Properties
	event := cmp.Or(props.Event, "Unknown")
	areaDesc := cmp.Or(props.AreaDesc, "Unknown")
	severity := cmp.Or(props.Severity, "Unknown")
	description := cmp.Or(props.Description, "No description available")
	instruction := cmp.Or(props.Instruction, "No specific instructions provided")

	return fmt.Sprintf(`
Event: %s
Area: %s
Severity: %s
Description: %s
Instruction: %s
`, event, areaDesc, severity, description, instruction)
}
```
<!--END_UTILS-FORMAT-ALERT-->
### `utils/categorize_local_weather.go`
<!--START_CATEGORIZE-LOCAL-WEATHER-->
```go
package utils

import (
	"fmt"
	"strings"
)

// Constant variables
const (
	HotThresholdF  = 80.0
	ColdThresholdF = 32.0
)

var (
	stormTerms   = []string{"thunder", "storm", "squall", "hail", "blizzard", "torrential"}
	rainTerms    = []string{"rain", "shower", "drizzle", "snow", "sleet", "freezing", "precipitation"}
	cloudTerms   = []string{"cloud", "overcast", "fog", "haze", "mist"}
	severeLevels = []string{"high", "severe", "extreme"}
)

// ForecastPeriod is one period of a NWS forecast response. The categorizer
// works from typed fields here; the loose key-alias handling of the Python
// variant belongs to its dict input and does not port to Go structs.
type ForecastPeriod struct {
	Name             string `json:"name"`
	Temperature      int    `json:"temperature"`
	TemperatureUnit  string `json:"temperatureUnit"`
	WindSpeed        string `json:"windSpeed"`
	WindDirection    string `json:"windDirection"`
	ShortForecast    string `json:"shortForecast"`
	DetailedForecast string `json:"detailedForecast"`
	Severity         string `json:"severity"`
}

// LocalWeather is the two styling values the GUI renders from.
type LocalWeather struct {
	Temperature   string `json:"Temperature"`
	Precipitation string `json:"Precipitation"`
}

// toFahrenheit converts a reported temperature to Fahrenheit.
func toFahrenheit(temperature float64, unit string) float64 {
	if strings.HasPrefix(strings.ToUpper(strings.TrimSpace(unit)), "C") {
		return temperature*9.0/5.0 + 32.0
	}
	return temperature
}

// categorizeTemperature buckets the reported temperature into hot, cold, or medium.
func categorizeTemperature(period ForecastPeriod) string {
	degrees := toFahrenheit(float64(period.Temperature), period.TemperatureUnit)

	if degrees >= HotThresholdF {
		return "hot"
	}
	if degrees < ColdThresholdF {
		return "cold"
	}
	return "medium"
}

// categorizePrecipitation buckets the reported conditions into stormy, cloudy, or sunny.
func categorizePrecipitation(period ForecastPeriod) string {
	conditions := strings.ToLower(period.DetailedForecast + " " + period.ShortForecast)
	severity := strings.ToLower(period.Severity)
	isSevere := false
	for _, level := range severeLevels {
		if severity == level {
			isSevere = true
			break
		}
	}

	containsAny := func(terms []string) bool {
		for _, term := range terms {
			if strings.Contains(conditions, term) {
				return true
			}
		}
		return false
	}

	if containsAny(stormTerms) {
		return "stormy"
	}
	if containsAny(rainTerms) {
		if isSevere {
			return "stormy"
		}
		return "cloudy"
	}
	if containsAny(cloudTerms) {
		return "cloudy"
	}
	return "sunny"
}

// CategorizeLocalWeather reduces a forecast period to the two styling values
// the GUI renders from: Temperature as one of hot, medium, cold, and
// Precipitation as one of stormy, cloudy, sunny.
func CategorizeLocalWeather(period ForecastPeriod) LocalWeather {
	return LocalWeather{
		Temperature:   categorizeTemperature(period),
		Precipitation: categorizePrecipitation(period),
	}
}

// FormatLocalWeather formats categorized weather as a single readable line.
func FormatLocalWeather(localWeather LocalWeather) string {
	temperature := localWeather.Temperature
	if temperature == "" {
		temperature = "medium"
	}
	precipitation := localWeather.Precipitation
	if precipitation == "" {
		precipitation = "sunny"
	}
	return fmt.Sprintf("Temperature: %s, Precipitation: %s", temperature, precipitation)
}
```
<!--END_CATEGORIZE-LOCAL-WEATHER-->
### `gui/gui_render_weather.go`
<!--START_GUI-RENDER-WEATHER-->
```go
// Package gui turns categorized weather into styling directives for GUI apps.
// The server owns the MCP instance and registers these functions as tools,
// which keeps gui/ importable from main.go without an import cycle.
package gui

import (
	"fmt"
	"strings"
	"time"

	"weather-server/utils"
)

// Constant variables
const (
	DayStartHour = 8  // 8AM
	DayEndHour   = 20 // 8PM
)

var timeLayouts = []string{"15:04:05", "15:04", "03:04:05 PM", "03:04 PM"}

// RenderWeatherDescription is the tool description the server registers for
// RenderWeather; the client acts on these directives.
const RenderWeatherDescription = `Render current GUI application based on local weather.
   A. If a file does not exist in repo that is compatible with this
      application, like "local-weather-style/STYLE.md", then:
       1. Determine application architecture
       2. Read styling
          - Analyze current styling
       3. Write to "local-weather-style/STYLE.md" how to update GUI apps
          styling next time this API is called
       4. Recurse to part "B"
   B. Else if the application is a ` + "`git`" + ` repo:
       1. If branch like "local-weather" exist, then:
          - run: ` + "`git checkout local-weather`" + `
          - else run: ` + "`git checkout -b local-weather`" + `
       2. Read "local-weather-style/STYLE.md"
       3. Update style according to arguments, and launch GUI
   C. Else:
      1. Do not make style changes
        - Do nothing, and exit

   The repoPath argument, when provided, names the repository of the GUI
   application parts A and B apply to.`

// HourOfDay returns the hour of day for a time given as text, or now when
// unparseable.
func HourOfDay(currentTime string) int {
	text := strings.TrimSpace(currentTime)
	for _, layout := range timeLayouts {
		if parsed, err := time.Parse(layout, text); err == nil {
			return parsed.Hour()
		}
	}

	// Unparseable input still has to render something, so fall back to now.
	return time.Now().Hour()
}

func styleOr(style, fallback string) string {
	if style == "" {
		return fallback
	}
	return style
}

// RenderWeather renders the current GUI application based on local weather.
func RenderWeather(localWeather utils.LocalWeather, currentTime string, repoPath string) string {
	hour := HourOfDay(currentTime)
	dayOrNight := "night"
	if hour >= DayStartHour && hour < DayEndHour {
		dayOrNight = "day"
	}
	temperatureStyle := styleOr(localWeather.Temperature, "medium")
	precipeStyle := styleOr(localWeather.Precipitation, "sunny")
	repoTarget := ""
	if repoPath != "" {
		repoTarget = fmt.Sprintf("- Apply Styling To Repo: %s\n", repoPath)
	}

	return fmt.Sprintf(`
%[4]s- Render Background: %[1]s
- Render Tone: %[2]s
- Precipitation Use: Set per %[3]s
- Copy Paste Assets Server Assets:
   - Determine GUI Application Context:
     - if game-like, then use assets, else do not use assets;
     - if game-like:
       - if "%[3]s" is "cloudy" or "stormy", then use cloud.svg
         - if "%[2]s" is "cold", then use snow.svg, else use rain.svg
       - else do not use cloud.svg, and style sky blue
     - if "%[1]s" is "day" use sun.svg, else use moon.svg
`, dayOrNight, temperatureStyle, precipeStyle, repoTarget)
}
```
<!--END_GUI-RENDER-WEATHER-->
### `gui/gui_draw_weather.go`
<!--START_GUI-DRAW-WEATHER-->
```go
package gui

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"weather-server/utils"
)

// Constant variables
const (
	dayAsset   = "sun.svg"
	nightAsset = "moon.svg"
	cloudAsset = "cloud.svg"
	rainAsset  = "rain.svg"
	snowAsset  = "snow.svg"
)

var overcastStyles = []string{"cloudy", "stormy"}

// Stand-in artwork for an asset the server does not ship, so the GUI always has
// something to draw. Deliberately plain, since it only holds the place.
const missingSvg = `<svg id="%[1]s" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 360">` +
	`<circle cx="180" cy="180" r="160" fill="#d2d2d2" stroke="#000" stroke-width="8"/>` +
	`<text x="180" y="196" fill="#000" font-family="sans-serif" font-size="44"` +
	` text-anchor="middle">%[2]s</text>` +
	`</svg>`

// DrawWeatherSvgDescription is the tool description the server registers for
// DrawWeatherSvg; the client acts on these directives.
const DrawWeatherSvgDescription = `Draw the SVG set for the current weather, as directives for the GUI app.

Each asset the server ships is drawn from disk. Any asset it does not
ship is drawn as a plain stand-in instead, so the draw set is never
short. When the server ships no asset at all, the directives ask for the
artwork to be generated rather than copied.`

// assetsDir resolves assets/ next to the compiled binary, falling back to the
// working directory when the binary path is unavailable.
func assetsDir() string {
	if exe, err := os.Executable(); err == nil {
		candidate := filepath.Join(filepath.Dir(exe), "assets")
		if info, err := os.Stat(candidate); err == nil && info.IsDir() {
			return candidate
		}
	}
	return "assets"
}

// drawSet returns the assets the current weather calls for, in draw order.
func drawSet(localWeather utils.LocalWeather, dayOrNight string) []string {
	temperatureStyle := styleOr(localWeather.Temperature, "medium")
	precipeStyle := styleOr(localWeather.Precipitation, "sunny")

	assets := []string{nightAsset}
	if dayOrNight == "day" {
		assets = []string{dayAsset}
	}
	for _, style := range overcastStyles {
		if precipeStyle != style {
			continue
		}
		assets = append(assets, cloudAsset)
		if temperatureStyle == "cold" {
			assets = append(assets, snowAsset)
		} else {
			assets = append(assets, rainAsset)
		}
		break
	}
	return assets
}

// clicheSvg draws the stand-in markup for an asset the server is missing.
func clicheSvg(asset string) string {
	name := strings.TrimSuffix(asset, filepath.Ext(asset))
	return fmt.Sprintf(missingSvg, name, strings.ToUpper(name))
}

// DrawWeatherSvg draws the SVG set for the current weather, as directives for
// the GUI app.
func DrawWeatherSvg(localWeather utils.LocalWeather, currentTime string) string {
	hour := HourOfDay(currentTime)
	dayOrNight := "night"
	if hour >= DayStartHour && hour < DayEndHour {
		dayOrNight = "day"
	}
	assets := drawSet(localWeather, dayOrNight)
	dir := assetsDir()

	var available []string
	var missing []string
	for _, asset := range assets {
		path := filepath.Join(dir, asset)
		if info, err := os.Stat(path); err == nil && !info.IsDir() {
			available = append(available, fmt.Sprintf("   - %s: %s", asset, path))
		} else {
			missing = append(missing, fmt.Sprintf("   - %s:\n     %s", asset, clicheSvg(asset)))
		}
	}

	// Nothing on disk to draw from, so the artwork has to be generated.
	if len(available) == 0 {
		return fmt.Sprintf(`
- Draw SVG Set: %s
- Generate SVG:
   - The server ships no asset for the current weather, so generate one SVG per
     name in the draw set
   - Match each one to the styling the GUI application already uses
   - Keep every viewBox square and the markup self contained, with no external
     references
`, strings.Join(assets, ", "))
	}

	serverPromptOutput := []string{fmt.Sprintf("- Draw SVG Set: %s", strings.Join(assets, ", "))}
	serverPromptOutput = append(serverPromptOutput, "- Draw From Server Assets:")
	serverPromptOutput = append(serverPromptOutput, available...)
	if len(missing) > 0 {
		serverPromptOutput = append(serverPromptOutput, "- Draw Stand-In, Server Ships No Asset:")
		serverPromptOutput = append(serverPromptOutput, missing...)
	}
	serverPromptOutput = append(serverPromptOutput,
		"- Add SVG Tool:",
		"   - For each language the GUI application is written in:",
		"     - Read the application and find the style pattern it already uses",
		"     - Add one lightweight SVG helper built on that style pattern:",
		"       - if the application groups behavior in classes, add a method",
		"       - else add a function",
		"     - The helper takes a name from the draw set and returns its markup",
		"   - Add no dependency, the helper stays lightweight",
	)

	return "\n" + strings.Join(serverPromptOutput, "\n") + "\n"
}
```
<!--END_GUI-DRAW-WEATHER-->

## Build Server

The project setup is deliberately different. Instead of one `main.go` file,
this server will have:

- Entry: `main.go`
- Helper functions: `utils/`
  - `make_nws_request.go`
  - `format_alert.go`
  - `categorize_local_weather.go`
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
- GUI rendering: `gui/`
  - `gui_render_weather.go`
  - `gui_draw_weather.go`
- GUI Graphics: `assets/`
  - `cloud.svg`
  - `sun.svg`
  - `moon.svg`
  - `rain.svg`
  - `snow.svg`

Build with `go build -o weather-server.exe .` so the binary sits next to `assets/`.

## Add Server

**Claude Desktop**

<CodeGroup>

```json macOS/Linux
"weather-server-gui": {
  "command": "/PATH/TO/weather-server/weather-server"
}
```

```json Windows
    "weather-server-gui": {
      "command": "D:\\Users\\name\\path\\to\\weather-server\\weather-server.exe"
    }
```

</CodeGroup>

## Additionally

- [go-sdk](https://github.com/modelcontextprotocol/go-sdk)
