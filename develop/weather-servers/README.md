# Weather Servers

One MCP weather server per language, each a variation of the official
[build-server tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server),
focusing on GUI API usage.

> [!NOTE]
> AGENT NOTE: Ignore shorthand like:
> - `(update.needed, .*)=>`
> - `(markedPages.index, .*)=>`

## The Constants

Every language folder repeats the same design, so it is documented once here.
Per-language READMEs carry only their language specifics.

### Tools

Each server exposes the same four tools (Java names arrive camelCase):

| Tool | Input | Returns |
| --- | --- | --- |
| `get_alerts` | `state` | Active NWS alerts for a US state |
| `get_forecast` | `latitude`, `longitude` | Next five forecast periods, plus a `Local Weather` line and render directives from the current period |
| `render_weather` | `temperature`, `precipitation`, `currentTime`, `repoPath` (optional) | Styling directives for a GUI application |
| `draw_weather_svg` | `temperature`, `precipitation`, `currentTime` | The SVG draw set for the current weather |

### GUI Variation

Beyond the tutorial, each server reduces the current forecast period to two
styling values (Temperature: `hot`/`medium`/`cold`; Precipitation:
`stormy`/`cloudy`/`sunny`), reads the local hour as day or night, and emits
directives a client can apply to a GUI application - including creating a
`local-weather-style/STYLE.md` and a `local-weather` branch when
`render_weather` names a target repository. The artwork ships once in
[assets/](assets/) (`cloud`, `moon`, `rain`, `snow`, `sun`) and copies into
each build.

### Build Scripts

Each folder carries a `buildExercise.bat` (Windows) and `buildExercise.sh`
(WSL/macOS) pair with the same two options:

```batch
buildExercise --build   :: extract the README into weather-server\ and compile
buildExercise --reset   :: remove weather-server\
```

The README is the source of truth: `--build` copies it to
`build_source.data.txt` and extracts every `<!--START_X-->` fenced section
into its target file, so editing a marker section and rebuilding is the whole
workflow.

### Use With Claude

Register a built server with Claude Code
(`claude mcp add --scope user weather-server-gui -- <launch command>`), or add
it to `mcpServers` in Claude Desktop's config and fully restart Desktop. Each
language README's "Use With Claude" section carries the exact launch command
for its build artifact.

## The Languages

| Folder | SDK | Entry | Build |
| --- | --- | --- | --- |
| [py](py/README.md) | `mcp` (uv) | `server.py` | `uv sync` |
| [ts](ts/README.md) | `@modelcontextprotocol/sdk` (npm) | `src/index.ts` | `npm run build` |
| [csharp](csharp/README.md) | `ModelContextProtocol` (dotnet) | `Program.cs` | `dotnet build` |
| [go](go/README.md) | `go-sdk` | `main.go` | `go build` |
| [java](java/README.md) | Spring AI MCP starter | `McpServerApplication.java` | `mvn clean package` |
| [kotlin](kotlin/README.md) | `kotlin-sdk` | `Main.kt` | `gradle build` |
| [ruby](ruby/README.md) | `mcp` gem | `weather.rb` | `bundle install` |
| [rust](rust/README.md) | `rmcp` (cargo) | `src/main.rs` | `cargo build --release` |

Java and Kotlin bootstrap their build tool when it is missing (into `.maven/`
and `.gradle-dist/` beside their scripts), so a JDK is the only prerequisite;
those caches deliberately survive `--reset`.

The py server predates the `repoPath` argument and registers its gui functions
directly from docstrings; the other seven follow the shared tool table above.
