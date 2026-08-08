# Develop MCP Server

> [!NOTE]
> AGENT NOTE: Ignore shorthand like:
> - `(update.needed, .*)=>`
> - `(markedPages.index, .*)=>`

## Connecting Local MCP Servers

**claude_desktop_config.json**

- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

**`mcpServer` Property** (*claude_desktop_config.json*)

```json
{
 "mcpServers": {
  "<name>": {
   "command": "<command>",
   "args": [
    "C:\\Users\\window\\os\\path\\index.js",
    "/Users/macOS/path/index.js",
    "[opt_1]",
    "[opt_2]",
    "[etc...]"
   ]
  }
 }
}
```

> [!NOTE]
> If using Claude Desktop, always exit the application to restart. Don't just
> close the window.

**Logs**

- macOS: `~/Library/Logs/Claude/mcp*.log`
- Windows: `%APPDATA%\Claude\logs\mcp*.log`

### Troubleshoot

**ENOENT error and `${APPDATA}` Windows Path**

- Expand the `%APPDATA% variable in `claude_desktop_config.json`

```json
{
  "brave-search": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-brave-search"],
    "env": {
      "APPDATA": "C:\\Users\\user\\AppData\\Roaming\\",
      "BRAVE_API_KEY": "..."
    }
  }
}
```

**NPM Installed Globally**

```bash
npm install -g npm
```

## MCP Servers

In order to get a solid understanding, each server will be a slight variation
of each one provided from the tutorial, and include one additional feature. The
additional feature will be the same for each server. It is a GUI API call that
can be plugged into HTML rendered applications.

Each server will also be built from a script. This is to get a solid foundation
of the entire process.

## The Exercises

Both families build the same way: each language folder's README carries the
full project inside `<!--START_X-->` fenced marker sections, and a
`buildExercise.bat`/`.sh` pair extracts them into a working project
(`--build`) or removes it (`--reset`). The shared design of each family is
documented once in its folder README; language folders keep only their own
specifics.

- [weather-servers/](weather-servers/README.md) - one MCP weather server per
  language. All expose the same four tools (`get_alerts`, `get_forecast`,
  `render_weather`, `draw_weather_svg`) plus the GUI styling variation drawn
  from shared SVG assets.
- [weather-clients/](weather-clients/README.md) - one MCP client per
  language. Each launches a built weather server over stdio and runs a chat
  loop where an Anthropic model calls its tools (needs `ANTHROPIC_API_KEY`).

## Additionally

- [Connect Remot MCP Server](https://modelcontextprotocol.io/docs/2026-07-28/develop/connect-remote-servers)
- [Agent Skills](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-with-agent-skills)
  - [`mcp-server-dev` plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/mcp-server-dev)
- [MCP SDKs](https://modelcontextprotocol.io/docs/2026-07-28/sdk)
