# exercise-mcp

- `Ctrl + click` for [documentation](https://isocialpractice.github.io/exercise-mcp/index.html)

This is a learning exercise where I went past the copy/paste procedure from the
tutorials provided from
[Model Context Protocol](https://modelcontextprotocol.io/docs/getting-started/intro),
and made implementing the server and/or client as hard as possible. To do so, I
studied and manually typed the code like it was the year 2017.

## The Gist

Every exercise here follows the same loop: the README of a project folder *is*
the project - full source inside `<!--START_X-->` fenced marker sections - and
a `buildExercise` script pair extracts those sections into a working build,
compiles it, and can reset it back to nothing. Typing, extracting, building,
and connecting the result to a real MCP client is the exercise.

| Folder | What it holds |
| --- | --- |
| [authorization/](authorization/README.md) | OAuth-protected MCP servers (TypeScript, Python, C#) that authenticate against a local Keycloak |
| [develop/](develop/README.md) | The tutorial variations: [weather-servers](develop/weather-servers/README.md) in eight languages and [weather-clients](develop/weather-clients/README.md) in seven |
| [modules/](modules/README.md) | Standalone modules built on the same tutorial: an interactive weather card ([weather_card-py](modules/weather_card-py/README.md)) and forecasts staged as showtunes ([weather-on-broadway](modules/weather-on-broadway/README.md)) |

The `develop` servers share one variation beyond the tutorial: four constant
tools (`get_alerts`, `get_forecast`, `render_weather`, `draw_weather_svg`)
where the GUI tools turn the current conditions into styling directives a
client can apply to a real application - branch, `STYLE.md`, and SVG assets
included. The built servers register with Claude Code (`claude mcp add`) or
Claude Desktop; each folder README's "Use With Claude" section has the exact
command, and the shared design of each family is documented once in its
folder README.

## Authorizations

For the authorizations servers, I made it even tougher in order to get a better
understanding. To do this I made a `buildExercise` script for each language.

**Getting Started**

Using Docker terminal:

```bash
docker run -p 127.0.0.1:8080:8080 -e KC_BOOTSTRAP_ADMIN_USERNAME=admin -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin quay.io/keycloak/keycloak start-dev
```

## Build Script

There are two portions for this exercise:

1. Authorization MCP Servers: [authorization](authorization)
2. Local MCP Servers: [develop](develop)

For each server in either portion there is a build script: `buildExercise`. It
can be called using either Windows or Linux. The script options are constant:

- `--build`: Build the server from raw data
- `--reset`: Put the server folder back in its initial state

With the `authorization` servers having an additional constant option:

- `--secure`: Clear the `KEYCLOAK_SECRET` data from the authorization file

Some scripts may have their own option, depending on the language and how it
can be used per OS. This exercise was built on Windows, using Windows Subsystem
for Linux (*WSL*); so language specific options will resolve conflicts in
regards to that.

In addition to that, each portion will have a global script that will handle
functions and/or subroutines that can be utilized by each of portion's
language script.

### Authorization Server with TypeScript

See [ts-server](authorization/ts-server/README.md).

### Authorization Server with Python

See [py-server](authorization/py-server/README.md).

## LICENSE

MIT
