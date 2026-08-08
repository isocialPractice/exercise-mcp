# Exercisie Module - Python Weather Card

> [!NOTE]
> These modules will probbly be 90-100% vibe coded, but still be based on the [server tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server)

## `(update.needed, proper README.md, write(mimic.exerciseExistingReadMeMd))=>`

### Start Edit Proper `README.md`

For a standalone feature, the compelling version fetches live conditions on
demand - one request when the tool is called, no background poll reaching into
the host - and renders them as the interactive card inside Claude Desktop.
Here's a fresh, self-contained module for that.New standalone module,
syntax-checked. It doesn't touch any of your existing files.

How it works as a feature: you ask Claude Desktop for the weather somewhere,
it calls `render_weather(location="Springfield, IL")`, the tool geocodes that
name and makes one on-demand call to the National Weather Service, and the
result comes back both as a text summary and as the interactive card rendered
in the sandboxed iframe. The card reads Claude Desktop's theme on init and
matches it; the condition just picks the accent color.

Ask without naming a place and it still works. The tool resolves a location in
this order, first hit wins: explicit `latitude`/`longitude`, then the
`location` name, then `WEATHER_CARD_DEFAULT_LOCATION` from your config, then
an approximate spot derived from your public IP. Only that last step tells a
third party anything about you, and only when the first three are empty - set
the env var in the config block below and it never runs. Everything stays
US-only, because NWS is.

To run it: `pip install mcp httpx` (mcp 2.x), then add the `weather-card` block
from the file's header to your `claude_desktop_config.json`
(Settings ▸ Developer ▸ Edit Config) with the absolute path, and restart. One
small edit before you ship - put a real contact string in `USER_AGENT`, since
NWS asks clients to identify themselves.

Two caveats I'd rather state than have you hit. The `# SDK:` spots are where
the SDK's surface drifts between versions - this module targets mcp 2.x
(`from mcp.server.mcpserver import MCPServer`); on mcp 1.x the same class lived
at `mcp.server.fastmcp.FastMCP` - so check them against your installed `mcp`.
And the NWS endpoint only covers US locations; if you want international
coverage you'd swap `_fetch_forecast` for a provider like Open-Meteo, and I can
write that version if you need it. (The geocoder is already Open-Meteo's, so a
non-US place resolves fine and then gets rejected with a plain message rather
than a confusing 404.)

Card not rendering? Three conditions have to hold, and this module got each of
them wrong once. The subtle one is the handshake: the view sends `ui/initialize`,
the host replies with `hostContext`, and only after the view sends
`ui/notifications/initialized` does the host deliver
`ui/notifications/tool-result`. The card now announces readiness on a short
timer rather than waiting on that reply, because a host that never answers
would otherwise deadlock it forever. The other two: the tool must carry
`_meta.ui.resourceUri` - that is what registering through the `Apps` extension
does for you, and note that `io.modelcontextprotocol/ui` is the extension's
negotiation identifier, not a `_meta` key, so using it as one fails silently.
And the result must carry `structuredContent`, which the card paints from; that
needs `structured_output=True` plus a `dict[str, Any]` return, because a bare
`-> dict` sends text only and leaves the card blank. Every call logs
`[weather-card] apps=<bool>` to stderr, visible in the MCP log - `apps=False`
means the host never negotiated MCP Apps and no server-side change will help.

When the card comes up empty it now diagnoses itself, because its iframe is
cross-origin and its console is awkward to reach from the chat window. The
second line reads either `init replied / N msgs`, meaning the host is talking
and the payload arrived in a shape the card did not recognise (the message
names are listed underneath, so start there), or `init no-reply / 0 msgs`,
meaning the host never spoke to the card at all. The second case is host-side
and nothing in this file will change it - see
[claude-ai-mcp issue 165](https://github.com/anthropics/claude-ai-mcp/issues/165)
and [issue 47](https://github.com/anthropics/claude-ai-mcp/issues/47). Every
inbound message is also logged as `[weather-card] rx`.

About the other weather card you may see: Claude Desktop renders its own weather
widget for weather-shaped questions, sourced from Google. It is a host feature,
not a competing MCP tool, so there is nothing to remove from
`claude_desktop_config.json`. This server can neither restyle it nor feed it
NWS data - it is host chrome, and this card lives in a sandboxed cross-origin
iframe that cannot reach the host's DOM, by browser policy and by the module's
DIRECTION OF CONTROL note. The two render independently.

One deliberate omission worth flagging: there's no timer here. Live data
arrives when the tool is called, not from a background loop - that's the honest
form of the "refresh the weather" idea, and it keeps the server from doing
anything on its own that you didn't ask for.

### End Edit Proper `README.md`

## Add to `claude_desktop_config.json`

<CodeGroup>

```json macOS/Linux
{
 "mcpServers": {
  "weather-card": {
    "command": "python",
    "args": ["/absolute/path/to/weather_card_app.py"],
    "env": { "WEATHER_CARD_DEFAULT_LOCATION": "Springfield, IL" }
  }
 }
}
```

```json Windows
{
 "mcpServers": {
  "weather-card": {
    "command": "python",
    "args": ["D:\\Users\\name\\path\\to\\weather_card_app.py"],
    "env": { "WEATHER_CARD_DEFAULT_LOCATION": "Springfield, IL" }
  }
 }
}
```

</CodeGroup>

`WEATHER_CARD_DEFAULT_LOCATION` is optional. Set it to your own city and a bare
"what's the weather?" answers for there without any IP lookup; leave it out and
the tool falls back to the public-IP estimate.
