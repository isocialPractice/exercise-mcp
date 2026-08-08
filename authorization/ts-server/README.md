# TypeScript Authorization Server

## Get Started

### Set OS Variables

See [authorization/README.md](../README.md)

### Server Files and Folders

Since this is an exercise, the focal elements: `main.ts, tsconfig.json`; are
not entirely ready for use. Instead the project structure can be built
utilizing the script `buildExercise`.

<CodeGroup>

```bash macOS/Linux
# Enusre to change to this folder.
cd authorization/<server-folder>
# Run the script
./buildExercise.sh --build
```

```batch Windows
:: Enusre to change to this folder.
cd authorization\<server-folder>
:: Run the script
buildExercise.bat --build
```

</CodeGroup>

Use the options below for further tinkering:

- `--reset`: Remove all built files and return the `<server-folder>` to it's
 original state
- `--secure`: Reset the `.env` file of `<server-folder>` to it's original state

### Update `.env` File

The `setOauth` script runs if the environment variables `_KEYCLOAK_ID` and
`_KEYCLOAK_SECRET` are set in the `buildExercise` script. If they are not, set
them accordingly. Once these variables are set, run the `setOauth` script to
update the `.env` file.

<CodeGroup>

```bash macOS/Linux
# Ensure to change to this folder
cd authorizations/<server-folder>
./setOauth.sh --set
```

```batch Windows
:: Enusre to change to this folder.
cd authorization\<server-folder>
:: Run the script
setOauth.bat --set
```

</CodeGroup>

To unset the variables in `.env` use the `--secure` option.

## TypeScript MCP Authorization Server

### JSON Files

<details>

<summary>Show Details</summary>

#### `package.json`

```json
{
 "name": "authorization-ts-server",
 "version": "0.0.0-alpha",
 "type": "module",
 "main": "dist/main.js",
 "scripts": {
  "build": "tsc -p tsconfig.json",
  "start": "node dist/main.js",
  "dev":   "tsx src/main.ts",
  "watch": "tsc -w -p tsconfig.json"
 },
 "dependencies": {
  "@modelcontextprotocol/sdk": "^1.17.2",
  "cors": "^2.8.5",
  "express": "^5.1.0",
  "dotenv": "^16.4.5",
  "zod": "^4.4.3"
 },
 "devDependencies": {
  "@types/cors": "^2.8.19",
  "@types/express": "^5.0.3",
  "@types/node": "^20.0.0",
  "tsx": "^4.0.0",
  "typescript": "^5.0.0"
 }
}
```

#### `tsconfig.json`

```json
{
 "compilerOptions": {
  "target": "ES2022",
  "module": "ES2022",
  "moduleResolution": "node",
  "allowSyntheticDefaultImports": true,
  "esModuleInterop": true,
  "outDir": "./dist",
  "rootDir": "./src",
  "strict": true,
  "declaration": false,
  "skipLibCheck": true,
  "forceConsistentCasingInFileNames": true
 },
 "include": [
  "src/**/*.ts"
 ],
 "exclude": [
  "node_modules",
  "dist"
 ]
}
```

#### `src/tsconfig.json`

```json
{
 "compilerOptions": {
  "target": "ES2022",
  "module": "ES2022",
  "moduleResolution": "node",
  "allowSyntheticDefaultImports": true,
  "esModuleInterop": true,
  "allowJs": true,
  "outDir": "./dist",
  "rootDir": "./",
  "strict": true,
  "declaration": true,
  "skipLibCheck": true,
  "forceConsistentCasingInFileNames": true
 },
 "include": [
  "*.ts"
 ],
 "exclude": [
  "node_modules",
  "dist"
 ]
}

```

</details>

### `src/main.ts`

```ts
import "dotenv/config";
import express from "express";
import { randomUUID } from "node:crypto";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import cors from "cors";
import {
  mcpAuthMetadataRouter,
  getOAuthProtectedResourceMetadataUrl,
} from "@modelcontextprotocol/sdk/server/auth/router.js";
import { requireBearerAuth } from "@modelcontextprotocol/sdk/server/auth/middleware/bearerAuth.js";
import { OAuthMetadata } from "@modelcontextprotocol/sdk/shared/auth.js";
import { checkResourceAllowed } from "@modelcontextprotocol/sdk/shared/auth-utils.js";
const CONFIG = {
  host: process.env.HOST || "localhost",
  port: Number(process.env.PORT) || 3000,
  auth: {
    host: process.env.AUTH_HOST || process.env.HOST || "localhost",
    port: Number(process.env.AUTH_PORT) || 8080,
    realm: process.env.AUTH_REALM || "master",
    clientId: process.env.OAUTH_CLIENT_ID || "mcp-server",
    clientSecret: process.env.OAUTH_CLIENT_SECRET || "",
  },
};

function createOAuthUrls() {
  const authBaseUrl = new URL(
    `http://${CONFIG.auth.host}:${CONFIG.auth.port}/realms/${CONFIG.auth.realm}/`,
  );
  return {
    issuer: authBaseUrl.toString(),
    introspection_endpoint: new URL(
      "protocol/openid-connect/token/introspect",
      authBaseUrl,
    ).toString(),
    authorization_endpoint: new URL(
      "protocol/openid-connect/auth",
      authBaseUrl,
    ).toString(),
    token_endpoint: new URL(
      "protocol/openid-connect/token",
      authBaseUrl,
    ).toString(),
  };
}

function createRequestLogger() {
  return (req: any, res: any, next: any) => {
    const start = Date.now();
    res.on("finish", () => {
      const ms = Date.now() - start;
      console.log(
        `${req.method} ${req.originalUrl} -> ${res.statusCode} ${ms}ms`,
      );
    });
    next();
  };
}

const app = express();

app.use(
  express.json({
    verify: (req: any, _res, buf) => {
      req.rawBody = buf?.toString() ?? "";
    },
  }),
);

app.use(
  cors({
    origin: "*",
    exposedHeaders: ["Mcp-Session-Id"],
  }),
);

app.use(createRequestLogger());

const mcpServerUrl = new URL(`http://${CONFIG.host}:${CONFIG.port}`);
const oauthUrls = createOAuthUrls();

const oauthMetadata: OAuthMetadata = {
  ...oauthUrls,
  response_types_supported: ["code"],
};

const tokenVerifier = {
  verifyAccessToken: async (token: string) => {
    const endpoint = oauthMetadata.introspection_endpoint;

    if (!endpoint) {
      console.error("[auth] no introspection endpoint in metadata");
      throw new Error("No token verification endpoint available in metadata");
    }

    const params = new URLSearchParams({
      token: token,
      client_id: CONFIG.auth.clientId,
    });

    if (CONFIG.auth.clientSecret) {
      params.set("client_secret", CONFIG.auth.clientSecret);
    }

    let response: Response;
    try {
      response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: params.toString(),
      });
    } catch (e) {
      console.error("[auth] introspection fetch threw", e);
      throw e;
    }

    if (!response.ok) {
      const txt = await response.text();
      console.error("[auth] introspection non-OK", { status: response.status });

      try {
        const obj = JSON.parse(txt);
        console.log(JSON.stringify(obj, null, 2));
      } catch {
        console.error(txt);
      }
      throw new Error(`Invalid or expired token: ${txt}`);
    }

    let data: any;
    try {
      data = await response.json();
    } catch (e) {
      const txt = await response.text();
      console.error("[auth] failed to parse introspection JSON", {
        error: String(e),
        body: txt,
      });
      throw e;
    }

    if (data.active === false) {
      throw new Error("Inactive token");
    }

    if (!data.aud) {
      throw new Error("Resource indicator (aud) missing");
    }

    const audiences: string[] = Array.isArray(data.aud) ? data.aud : [data.aud];
    const allowed = audiences.some((a) => {
      try {
        return checkResourceAllowed({
          requestedResource: a,
          configuredResource: mcpServerUrl,
        });
      } catch {
        return false;
      }
    });
    if (!allowed) {
      throw new Error(
        `None of the provided audiences are allowed. Expected ${mcpServerUrl}, got: ${audiences.join(", ")}`,
      );
    }

    return {
      token,
      clientId: data.client_id,
      scopes: data.scope ? data.scope.split(" ") : [],
      expiresAt: data.exp,
    };
  },
};
app.use(
  mcpAuthMetadataRouter({
    oauthMetadata,
    resourceServerUrl: mcpServerUrl,
    scopesSupported: ["mcp:tools"],
    resourceName: "MCP Demo Server",
  }),
);

const authMiddleware = requireBearerAuth({
  verifier: tokenVerifier,
  requiredScopes: [],
  resourceMetadataUrl: getOAuthProtectedResourceMetadataUrl(mcpServerUrl),
});

const transports: { [sessionId: string]: StreamableHTTPServerTransport } = {};

function createMcpServer() {
  const server = new McpServer({
    name: "authorization-ts-server",
    version: "0.0.0-alpha",
  });

  server.registerTool(
    "add",
    {
      title: "Addition Tool",
      description: "Add two numbers together",
      inputSchema: {
        a: z.number().describe("First number to add"),
        b: z.number().describe("Second number to add"),
      },
    },
    async ({ a, b }) => ({
      content: [{ type: "text", text: `${a} + ${b} = ${a + b}` }],
    }),
  );

  server.registerTool(
    "multiply",
    {
      title: "Multiplication Tool",
      description: "Multiply two numbers together",
      inputSchema: {
        x: z.number().describe("First number to multiply"),
        y: z.number().describe("Second number to multiply"),
      },
    },
    async ({ x, y }) => ({
      content: [{ type: "text", text: `${x} x ${y} = ${x * y}` }],
    }),
  );

  return server;
}

const mcpPostHandler = async (req: express.Request, res: express.Response) => {
  const sessionId = req.headers["mcp-session-id"] as string | undefined;
  let transport: StreamableHTTPServerTransport;

  if (sessionId && transports[sessionId]) {
    transport = transports[sessionId];
  } else if (!sessionId && isInitializeRequest(req.body)) {
    transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
      onsessioninitialized: (sessionId) => {
        transports[sessionId] = transport;
      },
    });

    transport.onclose = () => {
      if (transport.sessionId) {
        delete transports[transport.sessionId];
      }
    };

    const server = createMcpServer();
    await server.connect(transport);
  } else {
    res.status(400).json({
      jsonrpc: "2.0",
      error: {
        code: -32000,
        message: "Bad Request: No valid session ID provided",
      },
      id: null,
    });
    return;
  }

  await transport.handleRequest(req, res, req.body);
};

const handleSessionRequest = async (
  req: express.Request,
  res: express.Response,
) => {
  const sessionId = req.headers["mcp-session-id"] as string | undefined;
  if (!sessionId || !transports[sessionId]) {
    res.status(400).send("Invalid or missing session ID");
    return;
  }

  const transport = transports[sessionId];
  await transport.handleRequest(req, res);
};

app.post("/", authMiddleware, mcpPostHandler);
app.get("/", authMiddleware, handleSessionRequest);
app.delete("/", authMiddleware, handleSessionRequest);

app.listen(CONFIG.port, CONFIG.host, () => {
  console.log(`MCP Server running on ${mcpServerUrl.origin}`);
  console.log(`MCP endpoint available at ${mcpServerUrl.origin}`);
  console.log(
    `OAuth metadata available at ${getOAuthProtectedResourceMetadataUrl(mcpServerUrl)}`,
  );
});

```

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
