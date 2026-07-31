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
