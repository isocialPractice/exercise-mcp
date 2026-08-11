# Develop MCP Client

One MCP client per language, each a variation of the official
[build-client tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-client).
A client launches a weather server over stdio, lists its tools, and runs a
chat loop where an Anthropic model decides when to call them.

## The Constants

Every language folder repeats the same design, so it is documented once here.
Per-language READMEs carry only their language specifics.

- **README anatomy** - each README walks Setup Client Environment, Set API
  Key, the client code in `<!--START_X-->` fenced marker sections (a config
  section plus `CLIENT`), and an Exercise Command section showing the run.
- **API key** - each client reads `ANTHROPIC_API_KEY` from a git-ignored
  `.env` (or the environment). Keep real keys out of the READMEs; the build
  tooling fills `.env` from an environment variable.
- **Server pairing** - the client starts its server itself: pass the path of
  a built server entry file, for example
  `uv run client.py ../../weather-servers/py/weather-server/server.py`.
  Build the server first (see [weather-servers](../weather-servers/README.md)).
- **Build scripts** - `buildExercise.bat`/`.sh` exist for [py](py/) so far:
  `--build` extracts the marker sections, installs dependencies, and runs the
  client against the py server (building that server too when missing);
  `--reset` removes the project. The other folders share the same marker
  layout, so their script pairs can extract identically when added.

## The Languages

| Folder | Config sections | Client section |
| --- | --- | --- |
| [py](py/README.md) | `PYPROJECT` | `CLIENT` |
| [ts](ts/README.md) | `PACKAGE`, `TSCONFIG` | `CLIENT` |
| [csharp](csharp/README.md) | `CSPROJ` | `CLIENT` |
| [java](java/README.md) | `POM`, `APPLICATION-YML`, `SERVERS-CONFIG` | `CLIENT` |
| [kotlin](kotlin/README.md) | `SETTINGS-GRADLE`, `BUILD-GRADLE` | `CLIENT` |
| [ruby](ruby/README.md) | `GEMFILE` | `CLIENT` |
| [rust](rust/README.md) | `CARGO` | `CLIENT` |
