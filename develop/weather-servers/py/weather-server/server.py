# Import dependencies
from datetime import datetime
from mcp.server import MCPServer

# Import helpers
from utils.make_nws_request import make_nws_request
from utils.format_alert import format_alert
from utils.categorize_local_weather import categorize_local_weather, format_local_weather
from gui.gui_render_weather import render_weather

# Initialize server
mcp = MCPServer("weather-server")

# Constant variables
NWS_API_BASE = "https://api.weather.gov"
USER_AGENT = "weather-app/1.0"
LOCAL_TIME_FORMAT = "%H:%M:%S"

# render_weather is defined in gui/ so the module stays free of the server
# instance, so expose it as a tool from here.
mcp.tool()(render_weather)


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
