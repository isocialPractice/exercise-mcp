# Python Weather GUI Server

A variation of [weather-server-python](https://github.com/modelcontextprotocol/quickstart-resources/tree/main/weather-server-python) from the
[develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server#python),
focusing on GUI API usage.

> [!IMPORTANT]
> Don't write to stdout, or use the `print()` function.

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

- Tested on [vscode-py_maze](https://github.com/isocialPractice/vscode-py_maze/tree/local-weather)

## Quick Snippets

```
# output
logger.info("txt") # no print()

# project setup
uv add "mcp[cli]" # or `pip install "..."`

# build
from mcp.server import MCPServer
mcp = MCPServer("<server>")
```

<details>

<summary>Show Details</summary>

**Code**

```py
# Outputting
###############################################################################
import logging

logger = logging.getLogger(__name__)

# instead of print() use:
logger.info("Processing:") # writes to stderr

# Minimum Server
###############################################################################
from mcp.server import MCPServer

mcp = MCPServer("Demo")


@mcp.tool()
def add(a: int, b: int) -> int:
    """Add two numbers."""
    return a + b


@mcp.resource("greeting://{name}")
def greeting(name: str) -> str:
    """Greet someone by name."""
    return f"Hello, {name}!"

# Server Build
###############################################################################
from typing import Any
import httpx2
from mcp.server import MCPSerrver
mcp = MCPServer("<server>")

```

**Commands**

```bash
# Project Setup
###############################################################################
uv init <server> && cd <server>
uv venv
.venv\Scripts\activate
uv add <dependencies>
new-item <server>.py
```

</details>

## Setup Server Environment

1. Use `uv`

<CodeGroup>

```bash macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh
```

```batch Windows
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

</CodeGroup>

Restart the terminal.

2. Project setup

<CodeGroup>

```bash macOS/Linux
# Create a new directory for our project
uv init weather
cd weather

# Create virtual environment and activate it
uv venv
source .venv/bin/activate

# Install dependencies
uv add "mcp[cli]"

# Create our server file
touch weather.py
```

```batch Windows
:: Create directory
uv init weather-server
cd weather-server

:: Create and activate virutal environment
uv venv
.venv\Scripts\activate

:: Dependency installation
uv add mcp[cli]

:: Server files
new-item weather-server.py
```

</CodeGroup>

## Python MCP Server

The server created in this exercise a variation of the below file.
<!--START_PYPROJECT-->
```toml
[project]
name = "weather-server"
version = "0.1.0"
description = "A simple MCP weather server that renders a GUI from local conditions"
requires-python = ">=3.10"
dependencies = [
  "httpx2>=2.9",
  "mcp>=2.0.0rc1",
]
# Server runs as a script, so nothing is built or installed as a package.
[tool.uv]
package = false
```
<!--END_PYPROJECT-->
### `server.py`
<!--START_SERVER-->
```python
# Import dependencies
from datetime import datetime
from mcp.server import MCPServer

# Import helpers
from utils.make_nws_request import make_nws_request
from utils.format_alert import format_alert
from utils.categorize_local_weather import categorize_local_weather, format_local_weather
from gui.gui_render_weather import render_weather
from gui.gui_draw_weather import draw_weather_svg

# Initialize server
mcp = MCPServer("weather-server")

# Constant variables
NWS_API_BASE = "https://api.weather.gov"
USER_AGENT = "weather-app/1.0"
LOCAL_TIME_FORMAT = "%H:%M:%S"

# render_weather and draw_weather_svg are defined in gui/ so those modules stay
# free of the server instance, so expose them as tools from here.
mcp.tool()(render_weather)
mcp.tool()(draw_weather_svg)


def local_time() -> str:
    """Return the current local time, formatted for the GUI render tool."""
    return datetime.now().strftime(LOCAL_TIME_FORMAT)

@mcp.tool()
async def get_alerts(state: str) -> str:
    """Get weather alerts for a US state.

    Args:
        state: Two-letter US state code (e.g. CA, NY)
    """
    url = f"{NWS_API_BASE}/alerts/active/area/{state}"
    data = await make_nws_request(url)

    if not data or "features" not in data:
        return "Unable to fetch alert or alert not found."

    if not data["features"]:
        return "No active alert for the state."

    alerts = [format_alert(feature) for feature in data["features"]]
    return "\n---\n".join(alerts)

@mcp.tool()
async def get_forecast(latitude: float, longitude: float) -> str:
    """Get weather forecast for a location.

    Args:
        latitude: Latitude of the location
        longitude: Longitude of the location
    """
    # forecast grid endpoint
    points_url = f"{NWS_API_BASE}/points/{latitude},{longitude}"
    points_data = await make_nws_request(points_url)

    if not points_data:
        return "Unable to fetch forecast data for this location."

    # Get the forecast URL from points response
    forecast_url = points_data["properties"]["forecast"]
    forecast_data = await make_nws_request(forecast_url)

    if not forecast_data:
        return "Unable to fetch detailed forecast for this location."

    periods = forecast_data["properties"]["periods"]

    if not periods:
        return "No forecast periods available for this location."

    forecasts = []
    for period in periods[:5]: # next 5 periods
        forecast = f"""
{period["name"]}:
Temperature: {period["temperature"]}°{period["temperatureUnit"]}
Wind: {period["windSpeed"]} {period["windDirection"]}
Forecast: {period["detailedForecast"]}
"""
        forecasts.append(forecast)

    current_forecast = "\n---\n".join(forecasts)
    # The first period is the current one, so the GUI styles from it.
    render_data = categorize_local_weather(periods[0])
    render_directives = await render_weather(render_data, local_time())

    return f"""{current_forecast}
---
Local Weather: {format_local_weather(render_data)}
{render_directives}"""

if __name__ == "__main__":
    mcp.run(transport="stdio")
```
<!--END_SERVER-->
### `utils/make_nws_request.py`
<!--START_UTILS-MAKE-NWS-REQUEST-->
```python
# Import dependencies
from typing import Any

import httpx2

# Constant variables
USER_AGENT = "weather-app/1.0"


async def make_nws_request(url: str) -> dict[str, Any] | None:
    """Make a request to the NWS API with proper error handling."""
    headers = {"User-Agent": USER_AGENT, "Accept": "application/geo+json"}
    async with httpx2.AsyncClient() as client:
        try:
            response = await client.get(url, headers=headers, timeout=30.0)
            response.raise_for_status()
            return response.json()
        except Exception:
            return None
```
<!--END_UTILS-MAKE-NWS-REQUEST-->
### `utils/format_alert.py`
<!--START_UTILS-FORMAT-ALERT-->
```python
def format_alert(feature: dict) -> str:
    """Format an alert feature into a readable string."""
    props = feature["properties"]
    return f"""
Event: {props.get("event", "Unknown")}
Area: {props.get("areaDesc", "Unknown")}
Severity: {props.get("severity", "Unknown")}
Description: {props.get("description", "No description available")}
Instruction: {props.get("instruction", "No specific instructions provided")}
"""
```
<!--END_UTILS-FORMAT-ALERT-->
### `utils/categorize_local_weather.py`
<!--START_CATEGORIZE-LOCAL-WEATHER-->
```python
# Import dependencies
from typing import Any

# Constant variables
HOT_THRESHOLD_F = 80.0
COLD_THRESHOLD_F = 32.0
STORM_TERMS = ("thunder", "storm", "squall", "hail", "blizzard", "torrential")
RAIN_TERMS = ("rain", "shower", "drizzle", "snow", "sleet", "freezing", "precipitation")
CLOUD_TERMS = ("cloud", "overcast", "fog", "haze", "mist")
SEVERE_LEVELS = ("high", "severe", "extreme")

# NWS forecast periods and alert properties describe the same conditions under
# different key names, so each lookup below accepts either shape.
TEMPERATURE_KEYS = ("temperature", "temp")
UNIT_KEYS = ("temperatureUnit", "unit")
CONDITION_KEYS = ("detailedForecast", "shortForecast", "forecast", "event", "description")
SEVERITY_KEYS = ("severity",)


def _lookup(forecast: dict[str, Any], keys: tuple[str, ...], default: Any = "") -> Any:
    """Return the first populated value among keys, matched without case."""
    normalized = {str(key).lower(): value for key, value in forecast.items()}
    for key in keys:
        value = normalized.get(key.lower())
        if value is not None and value != "":
            return value
    return default


def _collect(forecast: dict[str, Any], keys: tuple[str, ...]) -> str:
    """Join every populated value among keys into one searchable string."""
    normalized = {str(key).lower(): value for key, value in forecast.items()}
    found = [
        str(normalized[key.lower()])
        for key in keys
        if normalized.get(key.lower()) is not None and normalized.get(key.lower()) != ""
    ]
    return " ".join(found)


def _to_fahrenheit(temperature: Any, unit: str) -> float | None:
    """Convert a reported temperature to Fahrenheit, or None when unusable."""
    try:
        degrees = float(temperature)
    except (TypeError, ValueError):
        return None

    if unit.strip().upper().startswith("C"):
        return degrees * 9.0 / 5.0 + 32.0
    return degrees


def _categorize_temperature(forecast: dict[str, Any]) -> str:
    """Bucket the reported temperature into hot, cold, or medium."""
    degrees = _to_fahrenheit(
        _lookup(forecast, TEMPERATURE_KEYS, default=None),
        str(_lookup(forecast, UNIT_KEYS, default="F")),
    )

    if degrees is None:
        return "medium"
    if degrees >= HOT_THRESHOLD_F:
        return "hot"
    if degrees < COLD_THRESHOLD_F:
        return "cold"
    return "medium"


def _categorize_precipitation(forecast: dict[str, Any]) -> str:
    """Bucket the reported conditions into stormy, cloudy, or sunny."""
    conditions = _collect(forecast, CONDITION_KEYS).lower()
    severity = str(_lookup(forecast, SEVERITY_KEYS)).lower()
    is_severe = severity in SEVERE_LEVELS

    if any(term in conditions for term in STORM_TERMS):
        return "stormy"
    if any(term in conditions for term in RAIN_TERMS):
        return "stormy" if is_severe else "cloudy"
    if any(term in conditions for term in CLOUD_TERMS):
        return "cloudy"
    return "sunny"


def categorize_local_weather(forecast: dict[str, Any]) -> dict[str, str]:
    """Reduce a forecast period to the two styling values the GUI renders from.

    Args:
        forecast: A NWS forecast period or alert properties mapping

    Returns:
        Mapping of "Temperature" to one of hot, medium, cold, and
        "Precipitation" to one of stormy, cloudy, sunny
    """
    return {
        "Temperature": _categorize_temperature(forecast),
        "Precipitation": _categorize_precipitation(forecast),
    }


def format_local_weather(local_weather: dict[str, str]) -> str:
    """Format categorized weather as a single readable line."""
    temperature = local_weather.get("Temperature", "medium")
    precipitation = local_weather.get("Precipitation", "sunny")
    return f"Temperature: {temperature}, Precipitation: {precipitation}"
```
<!--END_CATEGORIZE-LOCAL-WEATHER-->
### `gui/render_weather.py`
<!--START_GUI-RENDER-WEATHER-->
```python
# Import dependencies
from datetime import datetime, time
from typing import Any

# Constant variables
DAY_START_HOUR = 8   # 8AM
DAY_END_HOUR = 20    # 8PM
TIME_FORMATS = ("%H:%M:%S", "%H:%M", "%I:%M:%S %p", "%I:%M %p")

# The server owns the MCPServer instance and registers this coroutine as a tool,
# which keeps gui/ importable from server.py without a circular import.


def _hour_of_day(current_time: Any) -> int:
    """Return the hour of day for a time given as text, time, or datetime."""
    if isinstance(current_time, datetime):
        return current_time.hour
    if isinstance(current_time, time):
        return current_time.hour

    text = str(current_time).strip()
    for time_format in TIME_FORMATS:
        try:
            return datetime.strptime(text, time_format).hour
        except ValueError:
            continue

    # Unparseable input still has to render something, so fall back to now.
    return datetime.now().hour


async def render_weather(local_weather: dict, current_time) -> str:
    """Render current GUI application based on local weather.
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

       Args:
           local_weather: temperature, precipitation
           current_time: local time of day
    """
    hour = _hour_of_day(current_time)
    day_or_night = "day" if DAY_START_HOUR <= hour < DAY_END_HOUR else "night"
    temperature_style = local_weather.get("Temperature", "medium")
    precipe_style = local_weather.get("Precipitation", "sunny")

    server_prompt_output = f"""
- Render Background: {day_or_night}
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
"""

    return server_prompt_output
```
<!--END_GUI-RENDER-WEATHER-->
### `gui/draw_weather.py`
<!--START_GUI-DRAW-WEATHER-->
```python
# Import dependencies
from pathlib import Path

# Day and night already have one definition in the render module, and both
# modules ship in gui/, so reuse it rather than read the clock twice.
from gui.gui_render_weather import DAY_END_HOUR, DAY_START_HOUR, _hour_of_day

# Constant variables
ASSETS_DIR = Path(__file__).resolve().parent.parent / "assets"
DAY_ASSET = "sun.svg"
NIGHT_ASSET = "moon.svg"
CLOUD_ASSET = "cloud.svg"
RAIN_ASSET = "rain.svg"
SNOW_ASSET = "snow.svg"
OVERCAST_STYLES = ("cloudy", "stormy")

# Stand-in artwork for an asset the server does not ship, so the GUI always has
# something to draw. Deliberately plain, since it only holds the place.
MISSING_SVG = (
    '<svg id="{name}" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 360">'
    '<circle cx="180" cy="180" r="160" fill="#d2d2d2" stroke="#000" stroke-width="8"/>'
    '<text x="180" y="196" fill="#000" font-family="sans-serif" font-size="44"'
    ' text-anchor="middle">{label}</text>'
    "</svg>"
)

# The server owns the MCPServer instance and registers this coroutine as a tool,
# which keeps gui/ importable from server.py without a circular import.


def _draw_set(local_weather: dict, day_or_night: str) -> list[str]:
    """Return the assets the current weather calls for, in draw order."""
    temperature_style = local_weather.get("Temperature", "medium")
    precipe_style = local_weather.get("Precipitation", "sunny")

    draw_set = [DAY_ASSET if day_or_night == "day" else NIGHT_ASSET]
    if precipe_style in OVERCAST_STYLES:
        draw_set.append(CLOUD_ASSET)
        draw_set.append(SNOW_ASSET if temperature_style == "cold" else RAIN_ASSET)
    return draw_set


def _cliche_svg(asset: str) -> str:
    """Draw the stand-in markup for an asset the server is missing."""
    name = Path(asset).stem
    return MISSING_SVG.format(name=name, label=name.upper())


async def draw_weather_svg(local_weather: dict, current_time) -> str:
    """Draw the SVG set for the current weather, as directives for the GUI app.

       Each asset the server ships is drawn from disk. Any asset it does not
       ship is drawn as a plain stand-in instead, so the draw set is never
       short. When the server ships no asset at all, the directives ask for the
       artwork to be generated rather than copied.

       Args:
           local_weather: temperature, precipitation
           current_time: local time of day
    """
    hour = _hour_of_day(current_time)
    day_or_night = "day" if DAY_START_HOUR <= hour < DAY_END_HOUR else "night"
    draw_set = _draw_set(local_weather, day_or_night)

    available = []
    missing = []
    for asset in draw_set:
        path = ASSETS_DIR / asset
        if path.is_file():
            available.append(f"   - {asset}: {path}")
        else:
            missing.append(f"   - {asset}:\n     {_cliche_svg(asset)}")

    # Nothing on disk to draw from, so the artwork has to be generated.
    if not available:
        return f"""
- Draw SVG Set: {", ".join(draw_set)}
- Generate SVG:
   - The server ships no asset for the current weather, so generate one SVG per
     name in the draw set
   - Match each one to the styling the GUI application already uses
   - Keep every viewBox square and the markup self contained, with no external
     references
"""

    server_prompt_output = [f"- Draw SVG Set: {', '.join(draw_set)}"]
    server_prompt_output += ["- Draw From Server Assets:", *available]
    if missing:
        server_prompt_output += ["- Draw Stand-In, Server Ships No Asset:", *missing]
    server_prompt_output += [
        "- Add SVG Tool:",
        "   - For each language the GUI application is written in:",
        "     - Read the application and find the style pattern it already uses",
        "     - Add one lightweight SVG helper built on that style pattern:",
        "       - if the application groups behavior in classes, add a method",
        "       - else add a function",
        "     - The helper takes a name from the draw set and returns its markup",
        "   - Add no dependency, the helper stays lightweight",
    ]

    return "\n" + "\n".join(server_prompt_output) + "\n"
```
<!--END_GUI-DRAW-WEATHER-->

## Build Server

The project setup is deliberately different. Instead of one `<server>.py` file,
this server will have:

- Entry: `server.py`
- Helper functions: `utils/`
  - `make_nws_request.py`
  - `dormat_alert.py`
  - `categorize_local_weather.py`
    - Summary: for GUI instance of server, so weather will change display according to:
      - Hot, Mediumm, or Cold
        - Cold: **temp. < 32°F(0°C)**
        - Medium: **temp. > `cold` && temp. < 80°F(26.67°C)**
        - Hot: **temp. >= 80°F(26.67°C)**
        - Each determins effect for `["stormy", "cloudy", "sunny"]`
      - Stormy, Cloudy, or Sunny
        - If stormy or cloudy, then:
          - If stromy, then more precipitation; else less precipitation
          - If cold, then snow; else rain
          - If medium or hot, then:
            - Medium: more gray toned
            - Hot: more dark toned
- GUI rendering: `gui/`
  - `render_weather.py`
- GUI Graphics: `assets/`
  - `cloud.svg`
  - `sun.svg`
  - `precipitation.svg`

## Add Server

**Claude Desktop**

<CodeGroup>

```json macOS/Linux
"weather-server-gui": {
  "command": "uv",
  "args": [
    "--directory",
    "/PATH/TO/weather-server",
    "run",
    "server.py"
  ]
}
```

```json Windows
    "weather-server-gui": {
      "command": "uv",
      "args": [
        "--directory",
        "D:\\Users\\name\\path\\to\\weather-server",
        "run",
        "server.py"
      ]
    }
```

</CodeGroup>

## Additionally

- [python-sdk](https://github.com/modelcontextprotocol/python-sdk)
