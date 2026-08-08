# Exercise Modules

Standalone MCP servers built on the same
[weather tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server)
as the `develop` exercises, but taken somewhere new. Unlike the exercise
folders there is no `buildExercise` script - each module is a complete,
runnable project on its own, and largely vibe coded rather than hand-typed.

> [!NOTE]
> AGENT NOTE: Ignore shorthand like:
> - `(update.needed, .*)=>`
> - `(markedPages.index, .*)=>`

## The Modules

| Module | Language | The twist |
| --- | --- | --- |
| [weather_card-py](weather_card-py/README.md) | Python | Renders live conditions as an interactive card inside Claude Desktop - one on-demand NWS request per call, theme-matched to the host, no background polling |
| [weather-on-broadway](weather-on-broadway/README.md) | TypeScript | Stages the forecast as an original showtune - the current conditions pick the number, every period becomes a verse, and a marquee SVG bills the song |

## The Constants

- **Same data source** - both fetch from the National Weather Service, so
  only US locations work.
- **Register like any local server** - `claude mcp add --scope user <name> --
  <launch command>` for Claude Code, or an `mcpServers` entry in Claude
  Desktop's config followed by a full restart. Each module README carries its
  exact command.
- **Self-contained assets** - anything a module renders (card markup, song
  lyrics, SVG artwork) ships inside the module folder; the lyrics are
  original pastiche, not licensed material.
