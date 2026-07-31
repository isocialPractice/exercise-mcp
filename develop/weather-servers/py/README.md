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

(markedPages.index)=> {
    <CodeGroup>
      ```bash macOS/Linux theme={null}
      curl -LsSf https://astral.sh/uv/install.sh | sh
      ```

      ```powershell Windows theme={null}
      powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
      ```
    </CodeGroup>
}

```batch
powerrshell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Restart the terminal.

2. Project setup

(markedPages.index)=> {
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

## Build Server

The project setup is deliberately different. Instead of one `<server>.py` file,
this server will have:

- [Entry](main.py): `main.py`
- [Helper functions](utils): `utils/`
  - [make_nws_request.py](utils/make_nws_request.py)
  - [dormat_alert.py](utils/format_alert.py)
  - [categorize_local_weather.py](utils/categorize_local_weather.py): Summary
   for GUI instance of server, so weather will change display according to:
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
- [GUI rendering](gui): `gui/`
  - [render_weather.py](gui/render_weather.py)
- [GUI Graphics](assets): `assets/`
  - [cloud.svg](assets/cloud.svg)
  - [sun.svg](assets/sun.svg)
  - [precipitation.svg](assets/precipitation.svg)

## Additionally

- [python-sdk](https://github.com/modelcontextprotocol/python-sdk)