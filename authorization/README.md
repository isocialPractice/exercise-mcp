# Authorization Servers

## Get Started

<!-- ```
(markedPages.index, add.mdx.langTabSelect)=> {
<Tabs>
<Tab title="Windows">
### Set Windows Variables

**Requires Restart**

> [!NOTE]
> Ensure [Cygwin](https://www.cygwin.com/) dependency is installed

```batch
:: Set variable for reuse
setx _KEYCLOAK_ID "<client-name>"

:: Will have a value like "eyJhbGciOiJSUzI1N...etc."
setx _KEYCLOAK_SECRET "<client-secret>"
```
</Tab>

<Tab title="Linux">
### Set Linux Variables

```bash
# Update .bashrc file
vi ~/.bashrc

# Somewhere at the bottom add:
export _KEYCLOAK_ID="<client-name>"

# Will have a value like "eyJhbGciOiJSUzI1N...etc."
export _KEYCLOAK_SECRET="<client-secrect>"

# Save and run:
source ~/.bashrc
```
</Tab>
</Tabs>
}
``` -->

**Requires Restart**

> [!NOTE]
> Ensure [Cygwin](https://www.cygwin.com/) dependency is installed

```batch
:: Set variable for reuse
setx _KEYCLOAK_ID "<client-name>"

:: Will have a value like "eyJhbGciOiJSUzI1N...etc."
setx _KEYCLOAK_SECRET "<client-secret>"
```

## Authentication Server with [VS Code](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/authorization#testing-the-mcp-server)

### Step 1 - Start the server

**[ts-server](authorization/ts-server)**

```ts
npm run start
```

**[py-server](authorization/py-server)**

```python
uv sync
uv run mcp-simple-auth-rs
```

**[csharp-server](authorization/csharp-server)**

```csharp
dotnet run
```

### Step 2 - Add the server

- `Ctrl + Shift + P`: **MCP:Add server**
- Select `HTTP`
- Input `http://localhost:3000`
- Select either `Global` or `Workspace`

Next VS Code will open an authorization page in the browser. Approve, and the
server should now be usable from VS Code.

---

### Using in VS Code

**Prompt**

```
#multiply "(7 * 7)" "(2 * 4)"
```

**Response**

<details>

<summary>Show Details</summary>

```
I'll load and call the MCP authorization multiply tool for you. 



Ran Multiplication Tool 
Completed with input: {
  "x": 49,
  "y": 8
}

The result is **392** (49 x 8).
```

</details>

**Prompt**

```
set _one=#multiply "(7 * 7)" "(2 * 4)"
set _two=#add "$_one" "((4 + 5) * 20) + 19)"
#add "$_one" "$_two"
```

**Response**

<details>

<summary>Show Details</summary>

```
I'll execute this sequence of operations: 

Ran Multiplication Tool 
Completed with input: {
  "x": 49,
  "y": 8
}

Ran Addition Tool 
Completed with input: {
  "a": 392,
  "b": 199
}

Ran Addition Tool 
Completed with input: {
  "a": 392,
  "b": 591
}

The final result is **983**.

- `_one` = 392 (49 x 8)
- `_two` = 591 (392 + 199)  
- Final: 392 + 591 = 983
```

</details>

---

## Authentication Server with Claude Code

Claude Code doesn't have a pre-registered identity with your Keycloak. It
registers itself on the fly (Dynamic Client Registration), and then asks for
`mcp:tools` **plus** `offline_access` (so it can refresh the token without
making you sign in again). That auto-created client isn't allowed
`offline_access` in your Keycloak, so Keycloak rejects the whole request -
Keycloak's error message echoes the entire scope string, which is why you see
both scopes listed.

VS Code works because it doesn't ask for `offline_access`.

The clean fix: **create the client in Keycloak yourself**, give it both scopes,
and tell Claude Code to use it instead of self-registering. Then you control
both sides.

---

### Step 0 - Update Claude Code

```bash
claude --version
claude update
```

You want **v2.1.196 or newer**. Older versions requested every scope Keycloak
advertises, which fails on its own.

### Step 1 - Make sure both things are running

Keycloak on `:8080`, your MCP server on `:3000`. Sanity check:

```bash
curl -s http://localhost:3000/.well-known/oauth-protected-resource
```

You should see JSON containing `"scopes_supported":["mcp:tools"]`. If this
errors, fix the server before going further.

### Step 2 - Create a Keycloak client for Claude Code

Open `http://localhost:8080`, log in as `admin` / `admin`. Check the realm
selector top-left says **master**.

1. Left menu `->` **Clients** `->` **Create client**
2. Client type: **OpenID Connect**. Client ID: `claude-code` `->` **Next**
3. **Client authentication: Off**
 (_this makes it a public client - correct for a CLI tool_). Make sure
 **Standard flow** is checked `->` **Next**
4. **Valid redirect URIs**: `http://localhost:8123/callback`
 (_port doesn't matter_)
5. **Save**

> [!NOTE]
> The port `8123` is arbitrary - just remember it, you'll reuse it in Step 4.

### Step 3 - Give that client its scopes

Still inside the `claude-code` client:

1. Open the **Client scopes** tab
2. Look at the list. You need `mcp:tools` and `offline_access` both present.
3. If `mcp:tools` is missing: **Add client scope** `->` tick `mcp:tools` `->`
 **Add** `->` choose **Default**
4. If `offline_access` is missing: **Add client scope** `->` tick
 `offline_access` `->` **Add** `->` choose **Optional**

This is the step that actually fixes your error.

### Step 4 - Add the server in Claude Code

If you already added it under some name, clear it first:

```bash
claude mcp remove mathserver
claude mcp logout mathserver
```

Then add it with your hand-made client:

```bash
claude mcp add --transport http \
  --client-id claude-code --callback-port 8123 \
  mathserver http://localhost:3000
```

No `--client-secret` - you made it a public client, so there isn't one.

### Step 5 - Log in

```bash
claude mcp login mathserver
```

Your browser opens, you log in to Keycloak as `admin`, and you get a consent
screen for the `mcp:tools` scope. Approve it. The terminal should report
success.

### Step 6 - Verify

```bash
claude
```

Then inside the session:

```
/mcp
```

`mathserver` should show **connected** with 2 tools.

```
Use the add tool to add 41 and 1
```

Claude will ask permission to run; approve it, and you should get `42`.

---

### Using in Claude Code

**Prompt**

```bash
mcp__mathserver__add "10 + 2 * (3-1*(8*12/2)*20)" "12 + (23/(49*(50+2)/2))"
```

**Response**

<details>

<summary>Show Details</summary>

```
-1891.9819466248039

The add tool takes plain numbers, not expressions, so I evaluated each side first:

┌───────────────────────────────┬────────────────────┐
│          Expression           │       Value        │
├───────────────────────────────┼────────────────────┤
│ 10 + 2 * (3 - 1*(8*12/2)*20)  │ -1904              │
├───────────────────────────────┼────────────────────┤
│ 12 + (23 / (49 * (50 + 2)/2)) │ 12.018053375196232 │
└───────────────────────────────┴────────────────────┘

Working:
- Left: 8*12/2 = 48 → 1*48*20 = 960 → 3 - 960 = -957 → 2 * -957 = -1914 → 10 - 1914 = -1904
- Right: 50+2 = 52 → 49*52 = 2548 → /2 = 1274 → 23/1274 ≈ 0.0180533752 → +12
```

</details>

### Troubleshoot Claude Code Authorization

Get the exact request Claude Code is sending:

```bash
claude mcp login mathserver --no-browser
```

This prints the authorization URL instead of opening a browser. Look at the
`scope=` and `client_id=` parameters. Confirm `client_id=claude-code`
(_if it's a random UUID, the `--client-id` flag didn't take - re-check Step 4_),
then confirm every scope in that URL is listed on the client's
**Client scopes** tab in Keycloak.

Also check the Keycloak container logs - it usually names the offending scope
more precisely than the browser page does:

```bash
docker logs --tail 50 <keycloak-container-name>
```

Paste the `scope=` value and the log line here and I'll tell you exactly which
knob is wrong.
