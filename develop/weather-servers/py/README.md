# Python Weather GUI Server

A variation of [weather-server-python](https://github.com/modelcontextprotocol/quickstart-resources/tree/main/weather-server-python) from the
[develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server#python),
focusing on GUI API usage.

> [!IMPORTANT]
> Don't write to stdout, or use the `print()` function.

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

<!-- ```
(markedPages.index, add.mdx.langCodeGroupSelect)=> {
    <CodeGroup>
      ```bash macOS/Linux theme={null}
      curl -LsSf https://astral.sh/uv/install.sh | sh
      ```

      ```powershell Windows theme={null}
      powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
      ```
    </CodeGroup>
}
``` -->

```batch
powerrshell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Restart the terminal.

2. Project setup

<!-- ```
(markedPages.index, add.mdx.langCodeGroupSelect)=> {
    <CodeGroup>
      ```bash macOS/Linux theme={null}
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

      ```powershell Windows theme={null}
      # Create a new directory for our project
      uv init weather
      cd weather

      # Create virtual environment and activate it
      uv venv
      .venv\Scripts\activate

      # Install dependencies
      uv add mcp[cli]

      # Create our server file
      new-item weather.py
      ```
    </CodeGroup>
}
``` -->

```batch
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

## Server File

The server created in this exercise a variation of the below file.

```python
from typing import Any

import httpx2
from mcp.server import MCPServer

# Initialize MCPServer
mcp = MCPServer("weather")

# Constants
NWS_API_BASE = "https://api.weather.gov"
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


def format_alert(feature: dict) -> str:
    """Format an alert feature into a readable string."""
    props = feature["properties"]
    return f"""
Event: {props.get("event", "Unknown")}
Area: {props.get("areaDesc", "Unknown")}
Severity: {props.get("severity", "Unknown")}
Description: {props.get("description", "No description available")}
Instructions: {props.get("instruction", "No specific instructions provided")}
"""

@mcp.tool()
async def get_alerts(state: str) -> str:
    """Get weather alerts for a US state.

    Args:
        state: Two-letter US state code (e.g. CA, NY)
    """
    url = f"{NWS_API_BASE}/alerts/active/area/{state}"
    data = await make_nws_request(url)

    if not data or "features" not in data:
        return "Unable to fetch alerts or no alerts found."

    if not data["features"]:
        return "No active alerts for this state."

    alerts = [format_alert(feature) for feature in data["features"]]
    return "\n---\n".join(alerts)


@mcp.tool()
async def get_forecast(latitude: float, longitude: float) -> str:
    """Get weather forecast for a location.

    Args:
        latitude: Latitude of the location
        longitude: Longitude of the location
    """
    # First get the forecast grid endpoint
    points_url = f"{NWS_API_BASE}/points/{latitude},{longitude}"
    points_data = await make_nws_request(points_url)

    if not points_data:
        return "Unable to fetch forecast data for this location."

    # Get the forecast URL from the points response
    forecast_url = points_data["properties"]["forecast"]
    forecast_data = await make_nws_request(forecast_url)

    if not forecast_data:
        return "Unable to fetch detailed forecast."

    # Format the periods into a readable forecast
    periods = forecast_data["properties"]["periods"]
    forecasts = []
    for period in periods[:5]:  # Only show next 5 periods
        forecast = f"""
{period["name"]}:
Temperature: {period["temperature"]}°{period["temperatureUnit"]}
Wind: {period["windSpeed"]} {period["windDirection"]}
Forecast: {period["detailedForecast"]}
"""
        forecasts.append(forecast)

    return "\n---\n".join(forecasts)

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

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

<!-- ```
(markedPages.index, add.mdx.langCodeGroupSelect)=> {
    <CodeGroup>
      ```json macOS/Linux theme={null}
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

      ```json Windows theme={null}
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
}
``` -->

```json
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

## Additionally

- [python-sdk](https://github.com/modelcontextprotocol/python-sdk)
