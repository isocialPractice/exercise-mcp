# C# Authorization Server

A simple MCP resource server that validates OAuth tokens against a local
Keycloak authorization server via RFC 7662 token introspection, and exposes two
authenticated tools: `Add` and `Multiply`.

## Get Started

- .NET 9.0 or later
- A running client like Keycloak

### Install `.NET` on Linux

See:

- [Install .NET on Linux](https://learn.microsoft.com/en-us/dotnet/core/install/linux-scripted-manual)
- [Install .NET SDK on Ubuntu](https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu-install)

for more information.

**Install Script**

```bash
curl -L https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh
chmod +x ./dotnet-install.sh
./dotnet-install.sh --version latest

# Ensure it is running
$HOME/.dotnet/dotnet --info

# Set variable
vi ~/.bashrc
# Bottom of file add:
export DOTNET_ROOT=$HOME/.dotnet
# Save and run:
source ~/.bashrc

# Test variable
$DOTNET_ROOT/dotnet --info

# If all good delete download
rm -rf dotnet-install.sh
```

**Frameworks**

```bash
sudo apt update
sudo apt install -y dotnet-sdk-10.0
```

**ASP.NET**

```bash
sudo apt update
sudo apt install -y aspnetcore-runtime-10.0
sudo apt install -y dotnet-runtime-10.0
```

**Dependencies**

```bash
sudo apt install zlib1g
```

### Set OS Variables

```bash
# Edit .bashrc file.
vi ~/.bashrc

# At end of `~/.bashrc` add line.
export DOTNET_ROOT=$HOME/.dotnet

# Save and run:
source ~/.bashrc
```

### Server Files and Folders

Since this is an exercise, the server source files are not checked in ready to
run. The project structure is generated from `build_source.data.txt` by the
`buildExercise` script.

> [!NOTE]
> The build script uses `sed`. On Windows, ensure a `sed` binary is on `PATH`
> (for example via [Cygwin](https://www.cygwin.com/)).

<!-- ```
(markedPages.index, add.mdx.langCodeGroupSelect)=> {

    <CodeGroup>
      ```bash macOS/Linux theme={null}

      # Enusre to change to this folder.
      cd authorization/<server-folder>
      # Run the script
      ./buildExercise.sh --build
      ```

      ```powershell Windows theme={null}
      :: Enusre to change to this folder.
      cd authorization\<server-folder>
      :: Run the script
      buildExercise.bat --build
      ```
}
``` -->

```batch
:: Ensure you change to this folder.
cd authorization\<server-folder>
:: Run the script (generates files, runs `dotnet run`, starts the server)
buildExercise.bat --build
```

Use `--reset` to remove all generated files and return `csharp-server` to its
original state:

```batch
buildExercise --reset
```

### Configuration (no `.env` file)

This server does **not** use a `.env` file. Neither does it need credentials.
Instead it leans on standard ASP.NET Core builder pattern. This allows for the
built-in ASP.NET Core capabilities for token validation, and not the use of
Keycloak introspection endpoint.

## Starting the Server

The `buildExercise --build` step already starts the server. To build and run it
manually:

```bash
dotnet run
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
  "csharp-server/.vscode/mcp.json: my-mcp-server-f51abc5f": {
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
- Ensure the server is running (`dotnet run --framework net <version>`), and that the
  terminal stays open.

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
