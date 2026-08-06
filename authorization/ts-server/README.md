# TypeScript Authorization Server

## Get Started

### Set OS Variables

See [authorization/README.md](../README.md)

### Server Files and Folders

Since this is an exercise, the focal elements: `main.ts, tsconfig.json`; are
not entirely ready for use. Instead the project structure can be built
utilizing the script `buildExercise`.

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
:: Enusre to change to this folder.
cd authorization\<server-folder>
:: Run the script
buildExercise.bat --build
```

Use the options below for further tinkering:

- `--reset`: Remove all built files and return the `<server-folder>` to it's
 original state
- `--secure`: Reset the `.env` file of `<server-folder>` to it's original state

### Update `.env` File

The `setOauth` script runs if the environment variables `_KEYCLOAK_ID` and
`_KEYCLOAK_SECRET` are set in the `buildExercise` script. If they are not, set
them accordingly. Once these variables are set, run the `setOauth` script to
update the `.env` file.

<!-- ```
(markedPages.index, add.mdx.langCodeGroupSelect)=> {

    <CodeGroup>
      ```bash macOS/Linux theme={null}
      # Ensure to change to this folder
      cd authorizations/<server-folder>
      ./setOauth.sh --set
      ```

      ```powershell Windows theme={null}
      # Enusre to change to this folder.
      cd authorization\<server-folder>
      # Run the script
      setOauth.bat --set
      ```
}
``` -->

```batch
:: Enusre to change to this folder.
cd authorization\<server-folder>
:: Run the script
setOauth.bat --set
```

To unset the variables in `.env` use the `--secure` option.

## Starting the Server

After running the `buildExercise` script the server should be running, but if
not; `cd authorization/<server-folder>`, then build and run the server with:

```bash
# Either OS
npm install
npm run build
npm run start
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
> If `.vscode` folder exist, an additional `settings,json` file will be created
> with contents like:

```json
{
 "chat.mcp.serverSampling": {
  "ts-server/.vscode/mcp.json: my-mcp-server-f51abc5f": {
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

- Try `ctrl + shift + p` then:
  - `Authentication: Remove Dynamic Authentication Providers`
  - Select relevant `MCP Demo Server` and click **OK** to delete
- Ensure server is running with `npm run start`
- Add line to `main.ts` like:

```ts
    // Line 135-ish
    const audiences: string[] = Array.isArray(data.aud) ? data.aud : [data.aud];
    const allowed = audiences.some((a) => {
      try {
        return checkResourceAllowed({ requestedResource: a, configuredResource: mcpServerUrl });
      } catch {
        // Keycloak tokens include non-URL audiences (e.g. "account", "test-client").
        // Those are never our resource, so treat them as "no match" instead of crashing.
        return false;
      }
    });
```

If error `500` continues if above line added:

- Ensure the correct `OAUTH_CLIENT_ID` and `OAUTH_CLIENT_SECRET` values are set
 in the `.env` files
- Then restart the server, by:
  - If running in terminal `Ctrl + C`
  - Run `npm run start` after values have been updated in `.env`

### Trusted Hosts URI's

> [!NOTE]
> Don't prepend the URI with `http` protocol

After getting the computer's IP from running `ifconfig` (*Linux*) or `ipconfig`
(*Windows*), the Trusted Hosts should be like:

```
localhost:*
172.17.0.1
172.17.80.1
```
