# Rust Weather GUI Server

A variation of [weather-server-rust](https://github.com/modelcontextprotocol/quickstart-resources/tree/main/weather-server-rust) from the
[develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server#rust),
focusing on GUI API usage.

> [!IMPORTANT]
> Don't write to stdout, or use `println!()`.

## Use With Claude

Build the server first (see [Build Server](#build-server)), then register it.
The tools arrive as `get_alerts`, `get_forecast`, `render_weather`, and
`draw_weather_svg` under the `weather-server-gui` name.

**Claude Code (CLI or VS Code extension)**

Claude Code reads its own MCP config, not the Claude Desktop file:

```batch
claude mcp add --scope user weather-server-gui -- "D:\Users\name\path\to\weather-server\target\release\weather-server.exe"
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

- Tested on [napkin-sketch](https://github.com/isocialPractice/napkin-sketch/tree/local-weather)

## Quick Snippets

```
# output
eprintln!("txt") // writes to stderr, no println!()

# project setup
cargo new <server>
# add rmcp, tokio, reqwest, serde to Cargo.toml

# build
let service = Weather::new().serve(transport).await?;
```

<details>

<summary>Show Details</summary>

**Code**

```rust
// Outputting
///////////////////////////////////////////////////////////////////////////////
// instead of println!() use:
eprintln!("Processing:"); // writes to stderr

// Minimum Server
///////////////////////////////////////////////////////////////////////////////
use rmcp::{
    ServerHandler, ServiceExt,
    handler::server::router::tool::ToolRouter,
    model::*,
    tool, tool_handler, tool_router,
};

pub struct Demo {
    tool_router: ToolRouter<Demo>,
}

#[tool_router]
impl Demo {
    fn new() -> Self {
        Self { tool_router: Self::tool_router() }
    }

    #[tool(description = "Say hello.")]
    async fn hello(&self) -> String {
        "Hello!".to_string()
    }
}

#[tool_handler]
impl ServerHandler for Demo {
    fn get_info(&self) -> ServerInfo {
        ServerInfo {
            capabilities: ServerCapabilities::builder().enable_tools().build(),
            ..Default::default()
        }
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let transport = (tokio::io::stdin(), tokio::io::stdout());
    let service = Demo::new().serve(transport).await?;
    service.waiting().await?;
    Ok(())
}
```

**Commands**

```batch
:: Project Setup
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
cargo new <server>
cd <server>
:: add dependencies to Cargo.toml
cargo build --release
```

</details>

## Setup Server Environment

1. Use `rust` 1.70 or higher

```batch
rustc --version
cargo --version
```

2. Project setup

<CodeGroup>

```bash macOS/Linux
# Create a new Rust project
cargo new weather
cd weather
```

```batch Windows
:: Create project
cargo new weather-server
cd weather-server

:: Dependencies go in Cargo.toml, then verify the setup
cargo build
```

</CodeGroup>

## Rust MCP Server

The server created in this exercise is a variation of the below files.
<!--START_CARGO-->
```toml
[package]
name = "weather-server"
version = "0.1.0"
edition = "2024"

[dependencies]
rmcp = { version = "0.3", features = ["server", "macros", "transport-io"] }
tokio = { version = "1.46", features = ["full"] }
reqwest = { version = "0.12", features = ["json"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
anyhow = "1.0"
# The gui render tool falls back to the wall clock for unparseable times.
chrono = "0.4"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "std", "fmt"] }
```
<!--END_CARGO-->
### `src/main.rs`
<!--START_SERVER-->
```rust
// Import dependencies
use anyhow::Result;
use chrono::Local;
use rmcp::{
    ServerHandler, ServiceExt,
    handler::server::{router::tool::ToolRouter, tool::Parameters},
    model::*,
    schemars, tool, tool_handler, tool_router,
};

// Import helpers
mod categorize_local_weather;
mod gui_draw_weather;
mod gui_render_weather;
mod utils;

use categorize_local_weather::{categorize_local_weather, format_local_weather, LocalWeather};
use gui_draw_weather::draw_weather_svg;
use gui_render_weather::render_weather;
use utils::{format_alert, make_nws_request, AlertsResponse, ForecastResponse, PointsResponse};

// Constant variables
const NWS_API_BASE: &str = "https://api.weather.gov";
const LOCAL_TIME_FORMAT: &str = "%H:%M:%S";

/// Return the current local time, formatted for the GUI render tool.
fn local_time() -> String {
    Local::now().format(LOCAL_TIME_FORMAT).to_string()
}

#[derive(serde::Deserialize, schemars::JsonSchema)]
pub struct MCPForecastRequest {
    latitude: f32,
    longitude: f32,
}

#[derive(serde::Deserialize, schemars::JsonSchema)]
pub struct MCPAlertRequest {
    state: String,
}

/// The gui input every gui tool shares: the categorized weather and the local
/// time of day.
#[derive(serde::Deserialize, schemars::JsonSchema)]
pub struct MCPGuiRequest {
    /// Temperature style, one of hot, medium, cold
    temperature: String,
    /// Precipitation style, one of stormy, cloudy, sunny
    precipitation: String,
    /// Local time of day
    current_time: String,
    /// Repository of the GUI application to style
    repo_path: Option<String>,
}

pub struct Weather {
    tool_router: ToolRouter<Weather>,
}

#[tool_router]
impl Weather {
    fn new() -> Self {
        Self {
            tool_router: Self::tool_router(),
        }
    }

    #[tool(description = "Get weather alerts for a US state.")]
    async fn get_alerts(
        &self,
        Parameters(MCPAlertRequest { state }): Parameters<MCPAlertRequest>,
    ) -> String {
        let url = format!(
            "{}/alerts/active/area/{}",
            NWS_API_BASE,
            state.to_uppercase()
        );

        match make_nws_request::<AlertsResponse>(&url).await {
            Ok(data) => {
                if data.features.is_empty() {
                    "No active alert for the state.".to_string()
                } else {
                    data.features
                        .iter()
                        .map(format_alert)
                        .collect::<Vec<_>>()
                        .join("\n---\n")
                }
            }
            Err(_) => "Unable to fetch alert or alert not found.".to_string(),
        }
    }

    #[tool(description = "Get weather forecast for a location.")]
    async fn get_forecast(
        &self,
        Parameters(MCPForecastRequest {
            latitude,
            longitude,
        }): Parameters<MCPForecastRequest>,
    ) -> String {
        // forecast grid endpoint
        let points_url = format!("{NWS_API_BASE}/points/{latitude},{longitude}");
        let Ok(points_data) = make_nws_request::<PointsResponse>(&points_url).await else {
            return "Unable to fetch forecast data for this location.".to_string();
        };

        // Get the forecast URL from points response
        let forecast_url = points_data.properties.forecast;

        let Ok(forecast_data) = make_nws_request::<ForecastResponse>(&forecast_url).await else {
            return "Unable to fetch detailed forecast for this location.".to_string();
        };

        let periods = &forecast_data.properties.periods;
        if periods.is_empty() {
            return "No forecast periods available for this location.".to_string();
        }

        let current_forecast: String = periods
            .iter()
            .take(5) // next 5 periods
            .map(utils::format_period)
            .collect::<Vec<String>>()
            .join("\n---\n");

        // The first period is the current one, so the GUI styles from it.
        let render_data = categorize_local_weather(&periods[0]);
        let render_directives = render_weather(&render_data, &local_time(), None);

        format!(
            "{current_forecast}\n---\nLocal Weather: {}\n{render_directives}",
            format_local_weather(&render_data)
        )
    }

    // render_weather and draw_weather_svg live in their own modules so they
    // stay free of the server instance, so expose them as tools from here.

    #[tool(
        name = "render_weather",
        description = "Render current GUI application based on local weather.\n   A. If a file does not exist in repo that is compatible with this\n      application, like \"local-weather-style/STYLE.md\", then:\n       1. Determine application architecture\n       2. Read styling\n          - Analyze current styling\n       3. Write to \"local-weather-style/STYLE.md\" how to update GUI apps\n          styling next time this API is called\n       4. Recurse to part \"B\"\n   B. Else if the application is a `git` repo:\n       1. If branch like \"local-weather\" exist, then:\n          - run: `git checkout local-weather`\n          - else run: `git checkout -b local-weather`\n       2. Read \"local-weather-style/STYLE.md\"\n       3. Update style according to arguments, and launch GUI\n   C. Else:\n      1. Do not make style changes\n        - Do nothing, and exit\n\n   The repo_path argument, when provided, names the repository of the GUI\n   application parts A and B apply to."
    )]
    async fn render_weather_tool(
        &self,
        Parameters(MCPGuiRequest {
            temperature,
            precipitation,
            current_time,
            repo_path,
        }): Parameters<MCPGuiRequest>,
    ) -> String {
        let local_weather = LocalWeather {
            temperature,
            precipitation,
        };
        render_weather(&local_weather, &current_time, repo_path.as_deref())
    }

    #[tool(
        name = "draw_weather_svg",
        description = "Draw the SVG set for the current weather, as directives for the GUI app.\n\nEach asset the server ships is drawn from disk. Any asset it does not\nship is drawn as a plain stand-in instead, so the draw set is never\nshort. When the server ships no asset at all, the directives ask for the\nartwork to be generated rather than copied."
    )]
    async fn draw_weather_svg_tool(
        &self,
        Parameters(MCPGuiRequest {
            temperature,
            precipitation,
            current_time,
            // Arrives through the shared request; only the render tool reads it.
            repo_path: _,
        }): Parameters<MCPGuiRequest>,
    ) -> String {
        let local_weather = LocalWeather {
            temperature,
            precipitation,
        };
        draw_weather_svg(&local_weather, &current_time)
    }
}

#[tool_handler]
impl ServerHandler for Weather {
    fn get_info(&self) -> ServerInfo {
        ServerInfo {
            capabilities: ServerCapabilities::builder().enable_tools().build(),
            ..Default::default()
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let transport = (tokio::io::stdin(), tokio::io::stdout());
    let service = Weather::new().serve(transport).await?;
    service.waiting().await?;
    Ok(())
}
```
<!--END_SERVER-->
### `src/utils.rs`
<!--START_UTILS-->
```rust
// Import dependencies
use anyhow::Result;
use serde::Deserialize;
use serde::de::DeserializeOwned;

// Constant variables
const USER_AGENT: &str = "weather-app/1.0";

#[derive(Debug, Deserialize)]
pub struct AlertsResponse {
    pub features: Vec<AlertFeature>,
}

#[derive(Debug, Deserialize)]
pub struct AlertFeature {
    pub properties: AlertProperties,
}

#[derive(Debug, Deserialize)]
pub struct AlertProperties {
    pub event: Option<String>,
    #[serde(rename = "areaDesc")]
    pub area_desc: Option<String>,
    pub severity: Option<String>,
    pub description: Option<String>,
    pub instruction: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct PointsResponse {
    pub properties: PointsProperties,
}

#[derive(Debug, Deserialize)]
pub struct PointsProperties {
    pub forecast: String,
}

#[derive(Debug, Deserialize)]
pub struct ForecastResponse {
    pub properties: ForecastProperties,
}

#[derive(Debug, Deserialize)]
pub struct ForecastProperties {
    pub periods: Vec<ForecastPeriod>,
}

#[derive(Debug, Deserialize)]
pub struct ForecastPeriod {
    pub name: String,
    pub temperature: i32,
    #[serde(rename = "temperatureUnit")]
    pub temperature_unit: String,
    #[serde(rename = "windSpeed")]
    pub wind_speed: String,
    #[serde(rename = "windDirection")]
    pub wind_direction: String,
    #[serde(rename = "shortForecast", default)]
    pub short_forecast: String,
    #[serde(rename = "detailedForecast", default)]
    pub detailed_forecast: String,
    #[serde(default)]
    pub severity: String,
}

/// Make a request to the NWS API with proper error handling.
pub async fn make_nws_request<T: DeserializeOwned>(url: &str) -> Result<T> {
    let client = reqwest::Client::new();
    let rsp = client
        .get(url)
        .header(reqwest::header::USER_AGENT, USER_AGENT)
        .header(reqwest::header::ACCEPT, "application/geo+json")
        .send()
        .await?
        .error_for_status()?;
    Ok(rsp.json::<T>().await?)
}

/// Format an alert feature into a readable string.
pub fn format_alert(feature: &AlertFeature) -> String {
    let props = &feature.properties;
    format!(
        "\nEvent: {}\nArea: {}\nSeverity: {}\nDescription: {}\nInstruction: {}\n",
        props.event.as_deref().unwrap_or("Unknown"),
        props.area_desc.as_deref().unwrap_or("Unknown"),
        props.severity.as_deref().unwrap_or("Unknown"),
        props
            .description
            .as_deref()
            .unwrap_or("No description available"),
        props
            .instruction
            .as_deref()
            .unwrap_or("No specific instructions provided")
    )
}

/// Format one forecast period into a readable string.
pub fn format_period(period: &ForecastPeriod) -> String {
    format!(
        "\n{}:\nTemperature: {}°{}\nWind: {} {}\nForecast: {}\n",
        period.name,
        period.temperature,
        period.temperature_unit,
        period.wind_speed,
        period.wind_direction,
        period.detailed_forecast
    )
}
```
<!--END_UTILS-->
### `src/categorize_local_weather.rs`
<!--START_CATEGORIZE-LOCAL-WEATHER-->
```rust
// Import dependencies
use crate::utils::ForecastPeriod;

// Constant variables
const HOT_THRESHOLD_F: f64 = 80.0;
const COLD_THRESHOLD_F: f64 = 32.0;
const STORM_TERMS: [&str; 6] = ["thunder", "storm", "squall", "hail", "blizzard", "torrential"];
const RAIN_TERMS: [&str; 7] = [
    "rain",
    "shower",
    "drizzle",
    "snow",
    "sleet",
    "freezing",
    "precipitation",
];
const CLOUD_TERMS: [&str; 5] = ["cloud", "overcast", "fog", "haze", "mist"];
const SEVERE_LEVELS: [&str; 3] = ["high", "severe", "extreme"];

/// The two styling values the GUI renders from. The categorizer works from the
/// typed ForecastPeriod here; the loose key-alias handling of the Python
/// variant belongs to its dict input and does not port to structs.
pub struct LocalWeather {
    pub temperature: String,
    pub precipitation: String,
}

/// Convert a reported temperature to Fahrenheit.
fn to_fahrenheit(temperature: f64, unit: &str) -> f64 {
    if unit.trim().to_uppercase().starts_with('C') {
        temperature * 9.0 / 5.0 + 32.0
    } else {
        temperature
    }
}

/// Bucket the reported temperature into hot, cold, or medium.
fn categorize_temperature(period: &ForecastPeriod) -> String {
    let degrees = to_fahrenheit(f64::from(period.temperature), &period.temperature_unit);

    if degrees >= HOT_THRESHOLD_F {
        "hot".to_string()
    } else if degrees < COLD_THRESHOLD_F {
        "cold".to_string()
    } else {
        "medium".to_string()
    }
}

/// Bucket the reported conditions into stormy, cloudy, or sunny.
fn categorize_precipitation(period: &ForecastPeriod) -> String {
    let conditions = format!("{} {}", period.detailed_forecast, period.short_forecast).to_lowercase();
    let severity = period.severity.to_lowercase();
    let is_severe = SEVERE_LEVELS.contains(&severity.as_str());

    if STORM_TERMS.iter().any(|term| conditions.contains(term)) {
        "stormy".to_string()
    } else if RAIN_TERMS.iter().any(|term| conditions.contains(term)) {
        if is_severe {
            "stormy".to_string()
        } else {
            "cloudy".to_string()
        }
    } else if CLOUD_TERMS.iter().any(|term| conditions.contains(term)) {
        "cloudy".to_string()
    } else {
        "sunny".to_string()
    }
}

/// Reduce a forecast period to the two styling values the GUI renders from:
/// temperature as one of hot, medium, cold, and precipitation as one of
/// stormy, cloudy, sunny.
pub fn categorize_local_weather(period: &ForecastPeriod) -> LocalWeather {
    LocalWeather {
        temperature: categorize_temperature(period),
        precipitation: categorize_precipitation(period),
    }
}

/// Format categorized weather as a single readable line.
pub fn format_local_weather(local_weather: &LocalWeather) -> String {
    format!(
        "Temperature: {}, Precipitation: {}",
        local_weather.temperature, local_weather.precipitation
    )
}
```
<!--END_CATEGORIZE-LOCAL-WEATHER-->
### `src/gui_render_weather.rs`
<!--START_GUI-RENDER-WEATHER-->
```rust
// Import dependencies
use chrono::{Local, NaiveTime, Timelike};

use crate::categorize_local_weather::LocalWeather;

// Constant variables
pub const DAY_START_HOUR: u32 = 8; // 8AM
pub const DAY_END_HOUR: u32 = 20; // 8PM
const TIME_FORMATS: [&str; 4] = ["%H:%M:%S", "%H:%M", "%I:%M:%S %p", "%I:%M %p"];

// The server owns the rmcp service and registers this function as a tool,
// which keeps this module usable from main.rs without a circular reference.

/// Return the hour of day for a time given as text, or now when unparseable.
pub fn hour_of_day(current_time: &str) -> u32 {
    let text = current_time.trim();
    for time_format in TIME_FORMATS {
        if let Ok(parsed) = NaiveTime::parse_from_str(text, time_format) {
            return parsed.hour();
        }
    }

    // Unparseable input still has to render something, so fall back to now.
    Local::now().hour()
}

fn style_or<'a>(style: &'a str, fallback: &'a str) -> &'a str {
    if style.is_empty() { fallback } else { style }
}

/// Render current GUI application based on local weather.
///
/// local_weather: temperature, precipitation
/// current_time: local time of day
pub fn render_weather(
    local_weather: &LocalWeather,
    current_time: &str,
    repo_path: Option<&str>,
) -> String {
    let hour = hour_of_day(current_time);
    let day_or_night = if (DAY_START_HOUR..DAY_END_HOUR).contains(&hour) {
        "day"
    } else {
        "night"
    };
    let temperature_style = style_or(&local_weather.temperature, "medium");
    let precipe_style = style_or(&local_weather.precipitation, "sunny");
    let repo_target = repo_path
        .filter(|path| !path.is_empty())
        .map(|path| format!("- Apply Styling To Repo: {path}\n"))
        .unwrap_or_default();

    format!(
        r#"
{repo_target}- Render Background: {day_or_night}
- Render Tone: {temperature_style}
- Precipitation Use: Set per {precipe_style}
- Copy Paste Assets Server Assets:
   - Determine GUI Application Context:
     - if game-like, then use assets, else do not use assets;
     - if game-like:
       - if "{precipe_style}" is "cloudy" or "stormy", then use cloud.svg
         - if "{temperature_style}" is "cold", then use snow.svg, else use rain.svg
       - else do not use cloud.svg, and style sky blue
     - if "{day_or_night}" is "day" use sun.svg, else use moon.svg
"#
    )
}
```
<!--END_GUI-RENDER-WEATHER-->
### `src/gui_draw_weather.rs`
<!--START_GUI-DRAW-WEATHER-->
```rust
// Import dependencies
use std::env;
use std::path::PathBuf;

use crate::categorize_local_weather::LocalWeather;
// Day and night already have one definition in the render module, so reuse it
// rather than read the clock twice.
use crate::gui_render_weather::{hour_of_day, DAY_END_HOUR, DAY_START_HOUR};

// Constant variables
const DAY_ASSET: &str = "sun.svg";
const NIGHT_ASSET: &str = "moon.svg";
const CLOUD_ASSET: &str = "cloud.svg";
const RAIN_ASSET: &str = "rain.svg";
const SNOW_ASSET: &str = "snow.svg";
const OVERCAST_STYLES: [&str; 2] = ["cloudy", "stormy"];

// Stand-in artwork for an asset the server does not ship, so the GUI always
// has something to draw. Deliberately plain, since it only holds the place.
const MISSING_SVG: &str =
    r##"<svg id="{name}" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 360"><circle cx="180" cy="180" r="160" fill="#d2d2d2" stroke="#000" stroke-width="8"/><text x="180" y="196" fill="#000" font-family="sans-serif" font-size="44" text-anchor="middle">{label}</text></svg>"##;

/// Resolve assets/ next to the compiled binary first, then the working
/// directory, so `cargo run` and the release binary both find the artwork.
fn assets_dir() -> PathBuf {
    if let Ok(exe) = env::current_exe() {
        if let Some(dir) = exe.parent() {
            let candidate = dir.join("assets");
            if candidate.is_dir() {
                return candidate;
            }
        }
    }
    PathBuf::from("assets")
}

fn style_or<'a>(style: &'a str, fallback: &'a str) -> &'a str {
    if style.is_empty() { fallback } else { style }
}

/// Return the assets the current weather calls for, in draw order.
fn draw_set(local_weather: &LocalWeather, day_or_night: &str) -> Vec<&'static str> {
    let temperature_style = style_or(&local_weather.temperature, "medium");
    let precipe_style = style_or(&local_weather.precipitation, "sunny");

    let mut assets = vec![if day_or_night == "day" {
        DAY_ASSET
    } else {
        NIGHT_ASSET
    }];
    if OVERCAST_STYLES.contains(&precipe_style) {
        assets.push(CLOUD_ASSET);
        assets.push(if temperature_style == "cold" {
            SNOW_ASSET
        } else {
            RAIN_ASSET
        });
    }
    assets
}

/// Draw the stand-in markup for an asset the server is missing.
fn cliche_svg(asset: &str) -> String {
    let name = asset.strip_suffix(".svg").unwrap_or(asset);
    MISSING_SVG
        .replace("{name}", name)
        .replace("{label}", &name.to_uppercase())
}

/// Draw the SVG set for the current weather, as directives for the GUI app.
///
/// local_weather: temperature, precipitation
/// current_time: local time of day
pub fn draw_weather_svg(local_weather: &LocalWeather, current_time: &str) -> String {
    let hour = hour_of_day(current_time);
    let day_or_night = if (DAY_START_HOUR..DAY_END_HOUR).contains(&hour) {
        "day"
    } else {
        "night"
    };
    let assets = draw_set(local_weather, day_or_night);
    let dir = assets_dir();

    let mut available: Vec<String> = Vec::new();
    let mut missing: Vec<String> = Vec::new();
    for asset in &assets {
        let path = dir.join(asset);
        if path.is_file() {
            available.push(format!("   - {}: {}", asset, path.display()));
        } else {
            missing.push(format!("   - {}:\n     {}", asset, cliche_svg(asset)));
        }
    }

    // Nothing on disk to draw from, so the artwork has to be generated.
    if available.is_empty() {
        return format!(
            r#"
- Draw SVG Set: {}
- Generate SVG:
   - The server ships no asset for the current weather, so generate one SVG per
     name in the draw set
   - Match each one to the styling the GUI application already uses
   - Keep every viewBox square and the markup self contained, with no external
     references
"#,
            assets.join(", ")
        );
    }

    let mut server_prompt_output = vec![format!("- Draw SVG Set: {}", assets.join(", "))];
    server_prompt_output.push("- Draw From Server Assets:".to_string());
    server_prompt_output.extend(available);
    if !missing.is_empty() {
        server_prompt_output.push("- Draw Stand-In, Server Ships No Asset:".to_string());
        server_prompt_output.extend(missing);
    }
    server_prompt_output.extend(
        [
            "- Add SVG Tool:",
            "   - For each language the GUI application is written in:",
            "     - Read the application and find the style pattern it already uses",
            "     - Add one lightweight SVG helper built on that style pattern:",
            "       - if the application groups behavior in classes, add a method",
            "       - else add a function",
            "     - The helper takes a name from the draw set and returns its markup",
            "   - Add no dependency, the helper stays lightweight",
        ]
        .map(String::from),
    );

    format!("\n{}\n", server_prompt_output.join("\n"))
}
```
<!--END_GUI-DRAW-WEATHER-->

## Build Server

The project setup is deliberately different. Instead of one `src/main.rs` file,
this server will have:

- Entry: `src/main.rs`
- Helper functions:
  - `src/utils.rs`
  - `src/categorize_local_weather.rs`
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
- GUI rendering:
  - `src/gui_render_weather.rs`
  - `src/gui_draw_weather.rs`
- GUI Graphics: `assets/`
  - `cloud.svg`
  - `sun.svg`
  - `moon.svg`
  - `rain.svg`
  - `snow.svg`

Build with `cargo build --release`, which writes the binary to
`target/release/weather-server.exe`, then copy `assets/` next to the binary so
the draw tool finds the artwork.

## Add Server

**Claude Desktop**

<CodeGroup>

```json macOS/Linux
"weather-server-gui": {
  "command": "/PATH/TO/weather-server/target/release/weather-server"
}
```

```json Windows
    "weather-server-gui": {
      "command": "D:\\Users\\name\\path\\to\\weather-server\\target\\release\\weather-server.exe"
    }
```

</CodeGroup>

## Additionally

- [rust-sdk](https://github.com/modelcontextprotocol/rust-sdk)
