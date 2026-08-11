# Exercise Module - Python Weather Card

A Python MCP Apps server that answers a weather question with an interactive
card inside Claude Desktop. Ask for the weather somewhere, the model calls
`render_weather(location="Springfield, IL")`, and the tool geocodes that name,
makes one on-demand request to the National Weather Service, and returns the
result twice over - as a text summary for the model and as a card rendered in
the host's sandboxed iframe. The card reads the host's theme on init and
matches it; the condition picks only the accent color.

> [!NOTE]
> These modules are 90-100% vibe coded, but still based on the
> [server tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server).

## Tools

| Tool | Input | Returns |
| --- | --- | --- |
| `render_weather` | `location` ("City, ST"), or `latitude` + `longitude`, plus `days` (1-8, default 8) and `extra_html` | Current conditions over a day-by-day outlook strip, as the interactive card and a plain-text summary |

- `days=8` is the default, so a bare call already carries the outlook strip.
  `days=1` collapses the card to current conditions only. NWS publishes about a
  week out, so the strip holds 7-8 entries depending on the time of day.
- `extra_html` is the model's improve channel. For asks the card does not cover
  (hourly detail, active alerts, comparisons), the model fetches the NWS data
  itself and passes a small presentational fragment that renders below the
  panel. Scripts never execute there.

## How A Location Is Resolved

No API key, and no second server. The tool resolves a location in this order,
first hit wins:

1. `latitude` + `longitude` - an exact point, no lookup.
2. `location` - geocoded by name through Open-Meteo's keyless geocoder.
3. `WEATHER_CARD_DEFAULT_LOCATION` - the home location from the config block.
4. The host's public IP - approximate, city-level at best.

Only step 4 tells a third party anything about the caller, and it only runs
when the first three are empty. Set the environment variable and it never runs.
US locations only, because NWS is.

## Layout

- `weather_card_app.py` - the whole server: the tool, the `ui://weather/card`
  view, and the registration that links them
- `skills/improve-weather-answer/SKILL.md` - the exact NWS calls and the
  fragment shape to build for `extra_html`

## Requirements

```batch
pip install mcp httpx
```

This module targets mcp 2.x (`from mcp.server.mcpserver import MCPServer`); on
mcp 1.x the same class lived at `mcp.server.fastmcp.FastMCP`, so check the
imports against the installed `mcp`. One edit before shipping: put a real
contact string in `USER_AGENT`, since NWS asks clients to identify themselves.

## Use With Claude

**Claude Code (CLI or VS Code extension)**

```batch
claude mcp add --scope user weather-card -- python "D:\Users\name\path\to\weather_card_app.py"
```

Start a new session, then run `/mcp` to confirm the server connected. Hosts
without MCP Apps support get the plain-text summary instead of the card.

**Claude Desktop**

Add to `mcpServers` in `claude_desktop_config.json`
(Settings ▸ Developer ▸ Edit Config) with an absolute path, then fully quit
Claude Desktop from its tray icon and reopen it:

<CodeGroup>

```json macOS/Linux
    "weather-card": {
      "command": "python",
      "args": ["/absolute/path/to/weather_card_app.py"],
      "env": { "WEATHER_CARD_DEFAULT_LOCATION": "Springfield, IL" }
    }
```

```json Windows
    "weather-card": {
      "command": "python",
      "args": ["D:\\Users\\name\\path\\to\\weather_card_app.py"],
      "env": { "WEATHER_CARD_DEFAULT_LOCATION": "Springfield, IL" }
    }
```

</CodeGroup>

`WEATHER_CARD_DEFAULT_LOCATION` is optional. Set it to a home city and a bare
"what's the weather?" answers for there with no IP lookup; leave it out and the
tool falls back to the public-IP estimate.

## Example

**Prompt**

```text
What's the weather in Springfield, IL?
```

**Summary returned alongside the card**

```text
Springfield, IL - 14:22 - 91°F, Partly Sunny, 35% chance of precipitation.
Outlook: Thu 91/35%; Fri 88/20%; Sat 84/10%; Sun 86/0%; Mon 89/15%.
```

The card paints the same numbers: the temperature and condition pill up top,
the precipitation bar under it, and one column per day across the strip.

## When The Card Comes Up Blank

Three things have to hold, and each fails silently on its own, which is how a
card ends up mounted, empty, and invisible at the same time:

1. **`_meta.ui.resourceUri` on the tool.** Registering through the `Apps`
   extension stamps it. `io.modelcontextprotocol/ui` is the extension's
   negotiation identifier, not a `_meta` key - used as one it is ignored.
2. **`structuredContent` on the result.** The card paints from it, so the tool
   needs `structured_output=True` and a `dict[str, Any]` return. A bare
   `-> dict` gives the SDK no output schema, the payload ships as text only,
   and the card has nothing to draw.
3. **The three-step handshake.** The view sends `ui/initialize`, the host
   replies with `hostContext`, and only after the view sends
   `ui/notifications/initialized` does the host deliver the tool result. The
   card announces readiness on a 600ms timer rather than waiting for that
   reply, because a host that never answers would otherwise deadlock it.

If no result arrives within 2.5 seconds the card fetches the same NWS data
itself from inside the iframe - once, on render, no timer - using the connect
domains declared in the resource's CSP. So a blank card means even that failed:
check the MCP log, where every inbound message is logged as `[weather-card] rx`
and a failed fallback as `[weather-card] self-fetch failed`. A card that never
receives anything at all is host-side, and nothing in this module changes it -
see [claude-ai-mcp issue 165](https://github.com/anthropics/claude-ai-mcp/issues/165)
and [issue 47](https://github.com/anthropics/claude-ai-mcp/issues/47).

## Notes

- **The other weather card.** Claude Desktop renders its own weather widget for
  weather-shaped questions, sourced from Google. It is host chrome, not a
  competing MCP tool, so there is nothing to remove from
  `claude_desktop_config.json`. This server can neither restyle it nor feed it
  NWS data; the card lives in a sandboxed cross-origin iframe that cannot reach
  the host's DOM, by browser policy and by the module's DIRECTION OF CONTROL
  note.
- **No timer.** Live data arrives when the tool is called, not from a
  background loop. That is the honest form of "refresh the weather", and it
  keeps the server from doing anything unasked.
- **US only.** For international coverage, swap `_fetch_current` for a provider
  like Open-Meteo. The geocoder is already Open-Meteo's, so a non-US place
  resolves fine and is then rejected with a plain message rather than a
  confusing 404.
