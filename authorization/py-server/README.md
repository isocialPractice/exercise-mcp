# Python Authorization Server

A simple MCP resource server that validates OAuth tokens against a local
Keycloak authorization server via RFC 7662 token introspection, and exposes two
authenticated tools: `add_numbers` and `multiply_numbers`.

## Get Started

### Set OS Variables

See [authorization/README.md](../README.md)

### Install `uv`

See also [uv/installation](https://docs.astral.sh/uv/getting-started/installation/#winget)

```batch
winget install --id=astral-sh.uv -e
```

### Server Files and Folders

Since this is an exercise, the server source files are not checked in ready to
run. The project structure is generated from `build_source.data.txt` by the
`buildExercise` script.

> [!NOTE]
> The build script uses `sed`. On Windows, ensure a `sed` binary is on `PATH`
> (for example via [Cygwin](https://www.cygwin.com/)).

**Windows**

```batch
:: Ensure you change to this folder.
cd authorization\py-server
:: Run the script (generates files, runs `uv sync`, starts the server)
buildExercise.bat --build
```

**Linux**

```bash
# Ensure you change to this folder.
cd authorization/py-server
# Run the script (generates files, runs `uv sync`, starts the server)
./buildExercise.sh --build
```

Use `--reset` to remove all generated files and return `py-server` to its
original state:

```batch
buildExercise.bat --reset
```

### Configuration (no `.env` file)

This server does **not** use a `.env` file. Everything the TypeScript sample kept
in `.env` lives directly in [mcp_server/config.py](mcp_server/config.py) as a
class attribute: host, port, auth server location, and the OAuth client id and
secret. Environment variables of the same name still override a default when set,
but nothing has to be exported for the server to run.

Set the OAuth client id and secret to match the confidential client you created
in Keycloak (see the setup guide). The client id must be the same client whose
secret you paste, or introspection is rejected with `401`:

```python
# mcp_server/config.py
OAUTH_CLIENT_ID: str = os.getenv("OAUTH_CLIENT_ID", "test-client")
OAUTH_CLIENT_SECRET: str = os.getenv("OAUTH_CLIENT_SECRET", "<your-client-secret>")
```

## Starting the Server

The `buildExercise --build` step already starts the server. To build and run it
manually:

```bash
# Either OS
uv sync
uv run mcp-simple-auth-rs --port=3000 --auth-server=http://localhost:8080 --transport=streamable-http
```

A healthy server answers an unauthenticated request with `401` (it is up and
asking for a token):

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/
```

### Connect to Client

Assuming the instructions from
[authorization](https://modelcontextprotocol.io/docs/tutorials/security/authorization)
have been followed, in VS Code do:

1. Press `Ctrl + Shift + P`
2. Type and select `MCP: List Server`
  - If not listed do:
    - `Ctrl + Shift + P`
    - Type and select `MCP: Add server`
    - Select `HTTP`
    - Input `http://localhost:3000`
    - Then follow steps 1-3
3. Select the MCP Server

VS Code will prompt to open the browser, allow, login, and the MCP tools will
be registered.

> [!NOTE]
> If a `.vscode` folder exists, an additional `settings.json` file may be created
> with contents like:

```json
{
 "chat.mcp.serverSampling": {
  "py-server/.vscode/mcp.json: my-mcp-server-f51abc5f": {
   "allowedModels": [
    "copilotcli/auto",
    "copilot/auto",
    "copilotcli/claude-haiku-4.5"
   ]
  }
 }
}
```

## Troubleshooting

- Try `Ctrl + Shift + P` then:
  - `Authentication: Remove Dynamic Authentication Providers`
  - Select the relevant `MCP Resource Server` and click **OK** to delete
- Ensure the server is running (`uv run mcp-simple-auth-rs ...`), and that the
  terminal stays open.

### Introspection returns `401` / server returns `500`

The most common cause is a client mismatch. Confirm in
[mcp_server/config.py](mcp_server/config.py):

- `OAUTH_CLIENT_ID` matches the confidential client in Keycloak (for example
  `test-client`), and
- `OAUTH_CLIENT_SECRET` is that client's **Credentials -> Client Secret**.

Then restart the server. Unlike the TypeScript sample, the Python server needs no
`new URL` audience patch: `check_resource_allowed` uses `urlparse`, which
tolerates non-URL audiences (such as `account` and `test-client`) instead of
throwing.

### Trusted Hosts URIs

> [!NOTE]
> Do not prepend the URI with the `http` protocol.

After getting the computer's IP from running `ifconfig` (*Linux*) or `ipconfig`
(*Windows*), the Trusted Hosts should look like:

```
localhost:*
172.17.0.1
172.17.80.1
```
