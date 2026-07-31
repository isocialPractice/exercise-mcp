# Resolve the MCP Authorization Server (Start-to-Finish Guide)

This guide takes you from "nothing works" to "the tools show up in VS Code."
It assumes you have never set any of this up before, so every step says exactly
what to click, what to type, and what you should see. Follow it top to bottom.
Do not skip a step, even if you think it is already done. The checks are quick.

---

## Client Instructions

### 1. The 60-second mental model

There are **three** separate programs that all have to be running and agree with
each other. If any one of them is wrong, you get a confusing error.

| # | Piece | What it is | Where it runs |
|---|-------|-----------|---------------|
| 1 | **Keycloak** | The "bouncer." It logs users in and hands out tokens. | Docker, port `8080` |
| 2 | **MCP server** | Your app (`add` and `multiply` tools). It checks the token. | Node, port `3000` |
| 3 | **VS Code** | The client. It asks Keycloak for a token, then calls the MCP server. | Your editor |

The flow, in plain words:

1. VS Code calls the MCP server with no token. The server says "401, go get a token from Keycloak."
2. VS Code registers itself with Keycloak on the fly (this is called **DCR**, Dynamic Client Registration).
3. A browser opens. You log in. Keycloak gives VS Code a **token**.
4. VS Code calls the MCP server again, this time carrying the token.
5. The MCP server asks Keycloak "is this token real?" (this is called **introspection**). If yes, the tools appear.

Almost every failure below is one of those five steps not lining up. Keep the
table in mind and the errors stop being scary.

---

### 2. What you will need open

- **Docker Desktop** running (the whale icon in the tray is steady, not blinking).
- A **terminal** (PowerShell is fine).
- **VS Code**, with this project folder open.
- A **web browser**.

---

### 3. Part A - Make sure Keycloak is running

Keycloak is the bouncer. Start it if it is not already up.

**3.1** In a terminal, run:

```bash
docker ps
```

Look for a line that mentions `quay.io/keycloak/keycloak` with a status of `Up ...`.

- **If you see it:** good, Keycloak is running. Skip to 3.3.
- **If you do NOT see it:** start it with the command below.

**3.2** Start Keycloak (only if it was not already running):

```bash
docker run -p 127.0.0.1:8080:8080 -e KC_BOOTSTRAP_ADMIN_USERNAME=admin -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin quay.io/keycloak/keycloak start-dev
```

Leave that terminal window open. Keycloak writes its logs there, and you will
need those logs later.

> **Heads up: Keycloak in dev mode forgets everything when the container is
> recreated.** If you ever `docker run` a fresh container (not just restart the
> existing one), all the setup in Part A below is wiped and you have to redo it.
> This is the single most common reason things "randomly break again."

**3.3** Confirm you can reach it. Open this in your browser:

```
http://localhost:8080/realms/master/.well-known/openid-configuration
```

You should see a big blob of JSON. If you do, the bouncer is awake.

**3.4** Log into the Keycloak admin console (you will need it for the next steps):

- Go to `http://localhost:8080/admin/`
- Username `admin`, password `admin`
- Make sure the realm selector in the top-left says **master**.

---

### 4. Part B - Configure Keycloak (the part everyone gets wrong)

There are four things Keycloak needs. Three are about the **token**, one is about
**letting VS Code register**. Do all four.

**4.1** A scope called `mcp:tools`

A "scope" is a label that says what the token is allowed to do.

1. Left menu: **Client scopes**.
2. If `mcp:tools` is already in the list, open it and skip to step 5 below.
3. Otherwise click **Create client scope**. Name it exactly `mcp:tools`. Set
   **Type** to **Default**. Turn **Include in token scope** ON. Save.
4. Back on the list, make sure its **Assigned type** is **Default** (not Optional).
   If it says Optional, use the row menu to change it to Default. "Default" means
   every token automatically gets this scope without VS Code having to ask twice.

> Why "Default" matters: if the scope is Optional, tokens can come back without
> the audience info below, and the MCP server rejects them.

**4.2** Audience mapper #1 - the server's address

An "audience" (`aud`) is the token saying who it is *for*. The MCP server only
accepts tokens addressed to it.

1. Open the `mcp:tools` client scope.
2. Tab: **Mappers** -> **Configure a new mapper** -> choose **Audience**.
3. **Name:** `audience-config`
4. **Included Custom Audience:** `http://localhost:3000`
5. Leave "Add to access token" ON. Save.

This stamps `http://localhost:3000` into every token. The MCP server checks for
exactly this value.

**4.3** Audience mapper #2 - the introspection client (THE fix most guides miss)

This is the step that is missing from the basic tutorial and it will cost you an
hour if you skip it. Here is the trap, in plain words:

> When the MCP server asks Keycloak "is this token real?", **Keycloak 26 refuses
> to answer unless the MCP server's own client id is also listed in the token's
> audience.** If it is not, Keycloak replies `active: false` and the MCP server
> returns a blank `500` error with no explanation.

So the token needs **two** audiences: the server's address (4.2) *and* the
server's client id. Add the second one now.

1. Still in the `mcp:tools` client scope -> **Mappers** -> **Configure a new
   mapper** -> **Audience**.
2. **Name:** `introspection-audience`
3. This time use **Included Client Audience** (the dropdown, not the custom text
   box) and pick your MCP server's client, which is `test-client` (the one from
   step 4.5 / your `.env`).
4. Leave "Add to access token" ON. Save.

After this, tokens carry an audience list like
`["test-client", "http://localhost:3000", "account"]`. That satisfies both
Keycloak's introspection rule and the MCP server's address check.

> How to know you got this right: see the verification in Part F. If introspection
> says `active: true`, this step worked.

**4.4** Let VS Code register itself (Trusted Hosts / DCR)

By default Keycloak blocks unknown machines from registering clients. VS Code is
an unknown machine until you allow it. The catch: because Keycloak runs in Docker,
it does **not** see your request as coming from `localhost` or `127.0.0.1`. It
sees a Docker bridge address (commonly `172.17.0.1`). You have to allow that
exact address.

**Find the address Keycloak actually sees:**

1. Try to connect from VS Code once (Part E) so a registration attempt happens.
2. Look at the Keycloak terminal window (the one from step 3.2) for a line like:

   ```
   Failed to verify remote host : 172.17.0.1
   ```

   Whatever number is on that line is the one you need. (On many Docker Desktop
   setups it is `172.17.0.1`, but confirm yours.)

**Add it to Trusted Hosts:**

1. Admin console -> **Realm settings** is NOT where this lives; go to **Clients**
   in the left menu, then the **Client registration** tab, then **Trusted Hosts**.
2. Open the **Trusted Hosts** policy.
3. Turn **Client URIs Must Match** OFF.
4. In the **Trusted Hosts** list, add the address from the log (for example
   `172.17.0.1`). Keep it a plain address. Do **not** paste URLs like
   `http://localhost:*/*` - the policy matches hostnames and IPs, not URL patterns,
   so those entries do nothing.
5. Save.

> Simpler alternative for a throwaway dev setup: you can delete the Trusted Hosts
> policy entirely, which allows any local machine to register. Only do this on a
> local, disposable Keycloak - never in production.

**Confirm registration is allowed now.** In a terminal:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8080/realms/master/clients-registrations/openid-connect -H "Content-Type: application/json" -d "{\"client_name\":\"probe\",\"redirect_uris\":[\"http://127.0.0.1/cb\"],\"token_endpoint_auth_method\":\"none\"}"
```

- `201` means registration works. Good.
- `403` means the address is still wrong - go back and re-check the log line.

**4.5** A confidential client for the MCP server

The MCP server needs its own identity + password so it is allowed to call the
introspection endpoint.

1. Left menu: **Clients**. If a client named `test-client` already exists, open it
   and skip to step 6 to copy its secret.
2. Otherwise **Create client**. **Client ID:** `test-client`. Next.
3. Turn **Client authentication** ON (this makes it "confidential," meaning it has
   a secret). Next.
4. Save.
5. Open the client -> **Credentials** tab.
6. Copy the **Client Secret**. You need it for Part C.

---

### 5. Part C - Point the MCP server at Keycloak (`.env`)

#### TypeScript

Open the `.env` file in the project root and make sure it matches what you set up.
Replace the secret with the one you copied in 4.5. Do not share this file.

```env
HOST=localhost
PORT=3000

AUTH_HOST=localhost
AUTH_PORT=8080
AUTH_REALM=master

OAUTH_CLIENT_ID=test-client
OAUTH_CLIENT_SECRET=<paste-the-client-secret-from-step-4.5>
```

The `OAUTH_CLIENT_ID` here must be the **same** client you used in audience mapper
#2 (step 4.3). They are the same identity: the MCP server logging in to ask "is
this token real?"

---

### 6. Part D

#### TypeScript

> [!NOTE]
> Resolved: Fix the one code bug in `main.ts`

The sample server has a bug that only shows up with real Keycloak tokens, and it
disguises itself as a blank `500` error.

**What goes wrong:** the server loops over the token's audience list and calls
`new URL(...)` on each entry. Real tokens include non-URL entries like `account`
and `test-client`. `new URL("account")` throws an error, the whole check crashes,
and the crash is hidden behind a generic `500`.

**The fix:** skip entries that are not URLs instead of crashing on them.

Open [src/main.ts](../src/main.ts) and find this block (around line 135):

```typescript
const audiences: string[] = Array.isArray(data.aud) ? data.aud : [data.aud];
const allowed = audiences.some(a => checkResourceAllowed({ requestedResource: a, configuredResource: mcpServerUrl }));
```

Replace it with this:

```typescript
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

Save the file.

#### Python

**Good news: the `new URL` crash does not exist in Python.** The TypeScript bug
comes from `new URL("account")` throwing on non-URL audiences. The Python server
validates audiences with `check_resource_allowed(...)`, which uses
`urllib.parse.urlparse`. `urlparse` never throws on a non-URL string like
`account` or `test-client`; it just returns an empty scheme, so the audience
simply fails to match instead of crashing. On top of that, `verify_token` in
[py-server/mcp_server/token_verifier.py](py-server/mcp_server/token_verifier.py)
already wraps the whole introspection call in `try/except` and returns `None` on
any error. So there is no audience-loop patch to apply here.

**The Python fix is configuration, not code.** This server has **no `.env`
file.** Every property the TypeScript sample kept in `.env` (host, port, auth
server location, and the OAuth client id and secret) lives directly in
[py-server/mcp_server/config.py](py-server/mcp_server/config.py) as a class
attribute. Environment variables of the same name still override those defaults
when set, but nothing has to be exported for the server to run.

The 401 you see in the terminal is the introspection call itself being rejected:

```text
POST http://localhost:8080/realms/master/protocol/openid-connect/token/introspect "HTTP/1.1 401 Unauthorized"
```

That happens when `OAUTH_CLIENT_ID` does not match the client the secret belongs
to. The original default was `mcp-server`, but the confidential client created in
Part B (step 4.5) is `test-client`. Keycloak rejects the mismatched credentials
with `401`, `verify_token` returns `None`, and every request to the MCP server
401s in turn. Set the two OAuth values in `config.py` to your real client:

```python
# py-server/mcp_server/config.py
OAUTH_CLIENT_ID: str = os.getenv("OAUTH_CLIENT_ID", "test-client")
OAUTH_CLIENT_SECRET: str = os.getenv("OAUTH_CLIENT_SECRET", "<your-test-client-secret>")
```

`OAUTH_CLIENT_ID` here must be the **same** client you used in audience mapper #2
(step 4.3): the identity the MCP server logs in as to ask "is this token real?"

> Because the credentials are baked into `config.py`, the old `.env` /
> `setOauth` step is gone. `buildExercise` no longer writes an `.env` file; it
> generates the source, runs `uv sync`, and starts the server.

---

### 7. Part E - Build, run, and keep the server running

The MCP server does **not** rebuild itself. If you change code, you rebuild.

1. In a terminal, in the project folder:

   ```bash
   npm run build
   npm run start
   ```

2. You should see lines like:

   ```
   MCP Server running on http://localhost:3000
   OAuth metadata available at http://localhost:3000/.well-known/oauth-protected-resource
   ```

3. **Leave this terminal running.** This is a live server. If you close the window
   or press Ctrl+C, the server stops and VS Code will say "fetch failed" or
   "connection refused." A very common mistake is running `start`, seeing it work,
   closing the terminal, and wondering why it broke.

**Quick sanity check** (in a *second* terminal, so you do not stop the server):

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/
```

`401` is the **correct** answer here. It means "server is up and is asking for a
token." `000` or "connection refused" means the server is not running - go back
to step 1.

---

### 8. Part F - (Optional but recommended) Prove the token flow works before touching VS Code

VS Code adds its own layer of confusion. It is worth proving Keycloak + the server
work on their own first. This uses a test user so you are not relying on the
special `admin` account (the bootstrap `admin` is a temporary account and its
tokens often introspect as inactive - do not use it for this test).

**8.1** Create a normal test user (one time). In the admin console -> **Users** ->
**Add user**: username `demo-user`, then the **Credentials** tab -> **Set
password** -> `demo-pass`, turn **Temporary** OFF.

**8.2** Also, for this test only, open `test-client` -> **Settings** and turn
**Direct access grants** ON, Save. (This lets you grab a token with a password
instead of a browser. It is only for testing.)

**8.3** Get a token and check it end to end. Replace `<secret>` with your client
secret:

```bash
SECRET="<secret>"
TOKEN=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token --data-urlencode "grant_type=password" --data-urlencode "client_id=test-client" --data-urlencode "client_secret=$SECRET" --data-urlencode "username=demo-user" --data-urlencode "password=demo-pass" --data-urlencode "scope=mcp:tools" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

# Ask the server to accept it:
curl -s -o /dev/null -w "MCP server says: %{http_code}\n" -X POST http://localhost:3000/ -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" -H "Authorization: Bearer $TOKEN" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"curl\",\"version\":\"1.0\"}}}"
```

- `MCP server says: 200` means **everything on the server side works.** The rest is
  just VS Code.
- `MCP server says: 500` means introspection is failing. 99% of the time this is
  audience mapper #2 (step 4.3) missing, or you skipped the code fix in Part D.
- `MCP server says: 401` means the token was empty (the `TOKEN=` line failed) or
  the audience did not match.

---

### 9. Part G - Connect from VS Code

**9.1** Make sure the server entry exists. Open `.vscode/mcp.json`. It should have:

```json
{
  "servers": {
    "my-mcp-server": { "url": "http://localhost:3000", "type": "http" }
  }
}
```

(The exact name does not matter.)

**9.2 - IMPORTANT if you have been trying and failing already: clear VS Code's
stale login.** VS Code remembers the client it registered last time. If Keycloak
was recreated (see the warning in step 3.2), that remembered client no longer
exists in Keycloak, and you get **"Client not found"** in the browser with a weird
`client_id` that looks like two web addresses stuck together. This is a *stale
cache*, not a real config error. Clear it:

1. Press `Ctrl+Shift+P`.
2. Try these commands (names vary by VS Code version - use whichever exists):
   - **"Authentication: Remove Dynamic Client Registrations"**
   - **"MCP: Reset Cached Tokens"**
   - Or open the **Accounts** menu (bottom-left gear area), find any session tied to
     `localhost:8080`, and **Sign Out**.
3. If nothing else works, remove the server from `mcp.json`, save, add it back, save.

Skipping this step is the #1 reason "I fixed everything and it still says Client
not found."

**9.3** Start it. `Ctrl+Shift+P` -> **MCP: List Servers** -> pick your server ->
**Start Server**.

**9.4** A popup says the server "wants to authenticate." Click **Allow**.

**9.5** A browser opens to a Keycloak login page. Log in (use `demo-user` /
`demo-pass`, or any real realm user). Approve the `mcp:tools` consent if asked.

**9.6** The browser says you can return to VS Code. Back in VS Code, the tools
`add` and `multiply` should now appear under the server.

**9.7** Test a tool: open the Chat view, type `#`, pick `add`, and give it two
numbers.

---

### 10. Troubleshooting: symptom -> cause -> fix

Find your exact symptom. These are ordered roughly by where they appear in the flow.

| What you see | What it really means | Fix |
|---|---|---|
| VS Code: `fetch failed` / connection refused | The MCP server (port 3000) is not running. | Part E. Keep the terminal open. |
| `curl http://localhost:3000/` returns `000` | Same as above - server is down. | Part E. |
| Browser: **"Client not found"** with a `client_id` that looks like two URLs joined | VS Code is reusing a **stale** client it registered before Keycloak was recreated. | Step 9.2 - clear cached auth, then reconnect. |
| Keycloak log: `Failed to verify remote host : 172.17.0.1` and browser registration fails (`403`) | Keycloak does not trust the address the request came from. | Step 4.4 - add that exact address to Trusted Hosts. |
| VS Code: `Canceled: Canceled` a few milliseconds after discovering metadata | VS Code's own OAuth client gave up before opening a browser. Often a stale/failed registration or a VS Code version issue. | Step 9.2 first. If it persists, update VS Code or try VS Code Insiders - this has been a known client-side bug. |
| MCP server returns `500` with body `{"error":"server_error"}` and no detail | Token introspection failed *or* the audience check crashed. | Two causes: (a) audience mapper #2 missing -> step 4.3; (b) the `new URL` crash -> Part D. Do both. |
| Keycloak log: `Client 'test-client' is not in the token audience` | Introspection rejected because the server's client id is not in the token. | Step 4.3 - add the `test-client` audience mapper. |
| Introspection returns `active: false` but the token looks fine | You are testing with the bootstrap `admin` user, whose tokens introspect as inactive. | Use a normal user (`demo-user`), step 8.1. |
| Everything worked yesterday, broke today, and you restarted Docker | The Keycloak container was recreated and forgot all of Part B. | Redo Part B. Consider not deleting the container between sessions. |
| Tools still do not appear after a successful login | The server may have connected before the code fix; restart it. | Stop the server (Ctrl+C), `npm run build`, `npm run start`, reconnect. |

---

### 11. The one-minute checklist (pin this)

Before asking "why is it broken," confirm all of these are true:

#### TypeScript

- [x] Docker is running and Keycloak answers at `http://localhost:8080`.
- [x] `mcp:tools` scope exists, is **Default**, "Include in token scope" ON.
- [x] `mcp:tools` has **two** Audience mappers: `http://localhost:3000` **and** `test-client`.
- [x] Trusted Hosts includes the Docker bridge IP from the Keycloak log (registration probe returns `201`).
- [x] `test-client` exists, is confidential, and its secret is in `.env`.
- [x] `main.ts` audience check is wrapped in try/catch (Part D).
- [x] `npm run build` then `npm run start` was run, and the terminal is **still open**.
- [x] `curl http://localhost:3000/` returns `401` (server up, wants a token).
- [x] Part F test prints `200`.
- [x] VS Code cached auth was cleared before reconnecting (step 9.2).

If all ten boxes are checked and it still fails, the problem is almost certainly
VS Code's client itself - update it or try Insiders, and re-run Part F to prove
the server half is healthy.

#### Python

- [x] Docker is running and Keycloak answers at `http://localhost:8080`.
- [x] `mcp:tools` scope exists, is **Default**, "Include in token scope" ON.
- [x] `mcp:tools` has **two** Audience mappers: `http://localhost:3000` **and** `test-client`.
- [x] Trusted Hosts includes the Docker bridge IP from the Keycloak log (registration probe returns `201`).
- [x] `test-client` exists, is confidential, and its secret matches `OAUTH_CLIENT_SECRET` in `config.py`.
- [x] There is **no `.env` file**: host, port, auth server, and OAuth client id/secret all live in [py-server/mcp_server/config.py](py-server/mcp_server/config.py).
- [x] `OAUTH_CLIENT_ID` in `config.py` is `test-client` (not the old `mcp-server` default) so introspection authenticates.
- [x] No audience-loop code patch is required: `urlparse` tolerates non-URL audiences and `verify_token` already catches errors (Part D, Python).
- [x] `uv sync` then `uv run mcp-simple-auth-rs --port=3000 --auth-server=http://localhost:8080 --transport=streamable-http` was run, and the terminal is **still open**.
- [x] `curl http://localhost:3000/` returns `401` (server up, wants a token).
- [x] Part F test prints `200`.
- [x] VS Code cached auth was cleared before reconnecting (step 9.2).

If all boxes are checked and it still fails, the problem is almost certainly VS
Code's client itself - update it or try Insiders, and re-run Part F to prove the
server half is healthy.
