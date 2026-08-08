# Exercise Module - Weather on Broadway

A TypeScript MCP weather server that stages the forecast as an original
showtune. The current forecast period picks the number - sunny, cloudy,
stormy, and snowy conditions each land a different song, tempo, and chorus -
and every period becomes a verse with the real temperatures and winds sung
mid-line.

> [!NOTE]
> The songbook is original pastiche written for this exercise. No licensed
> Broadway lyrics appear anywhere in this module - any resemblance to a real
> showtune is strictly rhythmic.

## Tools

| Tool | Input | Returns |
| --- | --- | --- |
| `get_forecast` | `latitude`, `longitude` | The next five periods sung as verses of the mood's number, chorus included |
| `get_alerts` | `state` | Active alerts as the emergency ensemble number, one scene per alert |
| `get_playbill` | `mood` (optional) | The marquee SVG billed with the mood's showtune, plus the other stage assets |

## Layout

- `src/index.ts` - server, tools, and the NWS request helper
- `src/songbook.ts` - parses `assets/songbook.txt` at startup
- `src/broadway.ts` - mood detection, verse templates, stage directions
- `assets/songbook.txt` - the original numbers (title, tempo, chorus) per mood
- `assets/marquee.svg`, `curtain.svg`, `spotlight.svg`, `star.svg` - cliche
  stage graphics; the marquee takes the billed title at call time

## Build

```batch
cd modules\weather-on-broadway
npm install
npm run build
```

## Use With Claude

**Claude Code (CLI or VS Code extension)**

```batch
claude mcp add --scope user weather-on-broadway -- node "D:\Users\name\path\to\weather-on-broadway\build\index.js"
```

Start a new session, then run `/mcp` to confirm the server connected.

**Claude Desktop**

Add to `mcpServers` in `%APPDATA%\Claude\claude_desktop_config.json`, then
fully quit Claude Desktop from its tray icon and reopen it:

```json
    "weather-on-broadway": {
      "command": "node",
      "args": [
        "D:\\Users\\name\\path\\to\\weather-on-broadway\\build\\index.js"
      ]
    }
```

## Example

Ask for a forecast and the response arrives staged:

```text
WEATHER ON BROADWAY
Tonight's number: "Gray Matinee" (wistful waltz, 3/4)

[Curtain rises on a dim house. Somewhere, a lone clarinet.]

Verse 1:
   Tonight drifts in quietly, "Mostly Cloudy" on the bill,
   58 degrees, a 5 mph W sigh, the balcony sits still.
   (chorus)
   It's a gray matinee, pull the houselights low,
   ...
```

Only US locations work - the data comes from the National Weather Service.

### Claude Desktop Test

**Prompt**

```text
What's the weather like on broadway?
```

**Resonse**

```md
🎭 **"Thunder on Forty-Second"** — Tonight's weather drama on Broadway!

The forecast is unfolding as a dramatic act-one finale, complete with percussion in the heavens:

**Tonight:** Showers and thunderstorms take center stage at 75°F with a west wind at 5 mph. Hold onto your hats—the rain's crossing the footlights!

**Saturday:** A warming trend with highs near 90°F and mostly sunny conditions, though afternoon showers may encore (6-12 mph SW winds).

**Saturday Night:** Continued chances of showers and thunderstorms, cooling to 75°F.

**Sunday:** The weather turns sunny and clear—90°F with a west wind, perfect for a standing ovation.

**Sunday Night:** Mostly clear skies settle in at 73°F.

The show's a dramatic one this weekend—thunderstorms stealing the spotlight tonight and Saturday, with sunny breaks in between! 🌩️⚡
```
