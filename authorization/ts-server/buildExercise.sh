#!/bin/bash
# buildExercise
# Script for exercise, making a simple MCP server as hard as possible for learning purposes.

# Variable for this folder
_curDir="$(cd "$(dirname "$0")" && pwd)"
_ScriptName=$(basename "$0")

# Start in correct server folder
cd "$(dirname "$0")"

###### Support Functions #####
# Create package.json
function _packageJson {
 echo {
 echo \ {> "$_curDir/package.json"
 echo \ \ \"name\": \"authorization-ts-server\",
 echo \ \ \"name\": \"authorization-ts-server\",>> "$_curDir/package.json"
 echo \ \ \"version\": \"0.0.0-alpha\",
 echo \ \ \"version\": \"0.0.0-alpha\",>> "$_curDir/package.json"
 echo \ \ \"type\": \"module\",
 echo \ \ \"type\": \"module\",>> "$_curDir/package.json"
 echo \ \ \"main\": \"dist/main.js\",
 echo \ \ \"main\": \"dist/main.js\",>> "$_curDir/package.json"
 echo \ \ \"scripts\": {
 echo \ \ \"scripts\": {>> "$_curDir/package.json"
 echo \ \ \ \"build\": \"tsc -p tsconfig.json\",
 echo \ \ \ \"build\": \"tsc -p tsconfig.json\",>> "$_curDir/package.json"
 echo \ \ \ \"start\": \"node dist/main.js\",
 echo \ \ \ \"start\": \"node dist/main.js\",>> "$_curDir/package.json"
 echo \ \ \ \"dev\":   \"tsx src/main.ts\",
 echo \ \ \ \"dev\":   \"tsx src/main.ts\",>> "$_curDir/package.json"
 echo \ \ \ \"watch\": \"tsc -w -p tsconfig.json\"
 echo \ \ \ \"watch\": \"tsc -w -p tsconfig.json\">> "$_curDir/package.json"
 echo \ \ },
 echo \ \ },>> "$_curDir/package.json"
 echo \ \ \"dependencies\": {
 echo \ \ \"dependencies\": {>> "$_curDir/package.json"
 echo \ \ \ \"@modelcontextprotocol/sdk\": \"^1.17.2\",
 echo \ \ \ \"@modelcontextprotocol/sdk\": \"^1.17.2\",>> "$_curDir/package.json"
 echo \ \ \ \"cors\": \"^2.8.5\",
 echo \ \ \ \"cors\": \"^2.8.5\",>> "$_curDir/package.json"
 echo \ \ \ \"express\": \"^5.1.0\",
 echo \ \ \ \"express\": \"^5.1.0\",>> "$_curDir/package.json"
 echo \ \ \ \"dotenv\": \"^16.4.5\",
 echo \ \ \ \"dotenv\": \"^16.4.5\",>> "$_curDir/package.json"
 echo \ \ \ \"zod\": \"^4.4.3\"
 echo \ \ \ \"zod\": \"^4.4.3\">> "$_curDir/package.json"
 echo \ \ },
 echo \ \ },>> "$_curDir/package.json"
 echo \ \ \"devDependencies\": {
 echo \ \ \"devDependencies\": {>> "$_curDir/package.json"
 echo \ \ \ \"@types/cors\": \"^2.8.19\",
 echo \ \ \ \"@types/cors\": \"^2.8.19\",>> "$_curDir/package.json"
 echo \ \ \ \"@types/express\": \"^5.0.3\",
 echo \ \ \ \"@types/express\": \"^5.0.3\",>> "$_curDir/package.json"
 echo \ \ \ \"@types/node\": \"^20.0.0\",
 echo \ \ \ \"@types/node\": \"^20.0.0\",>> "$_curDir/package.json"
 echo \ \ \ \"tsx\": \"^4.0.0\",
 echo \ \ \ \"tsx\": \"^4.0.0\",>> "$_curDir/package.json"
 echo \ \ \ \"typescript\": \"^5.0.0\"
 echo \ \ \ \"typescript\": \"^5.0.0\">> "$_curDir/package.json"
 echo \ \ }
 echo \ }>> "$_curDir/package.json"
 echo }
 echo }>> "$_curDir/package.json"
}

# Create the tsconfig.json
function _tsconfig {
 if [ "$1" == "--root" ]; then
  _tsconfigFile="$_curDir/tsconfig.json"
 else
  if [ ! -e "src" ]; then
   mkdir src
  fi
  _tsconfigFile="$_curDir/src/tsconfig.json"
 fi
 # start per condition
 echo
 echo Making \`$_tsconfigFile\`
 echo {
 echo {>"$_tsconfigFile"
 echo \  \"compilerOptions\": {
 echo \  \"compilerOptions\": {>>"$_tsconfigFile"
 echo \ \ \"target\": \"ES2022\",
 echo \ \ \"target\": \"ES2022\",>>"$_tsconfigFile"
 echo \ \ \"module\": \"ES2022\",
 echo \ \ \"module\": \"ES2022\",>>"$_tsconfigFile"
 echo \ \ \"moduleResolution\": \"node\",
 echo \ \ \"moduleResolution\": \"node\",>>"$_tsconfigFile"
 echo \ \ \"allowSyntheticDefaultImports\": true,
 echo \ \ \"allowSyntheticDefaultImports\": true,>>"$_tsconfigFile"
 echo \ \ \"esModuleInterop\": true,
 echo \ \ \"esModuleInterop\": true,>>"$_tsconfigFile"
 if [ "$1" == "--src" ]; then
  echo \ \ \"allowJs\": true,
  echo \ \ \"allowJs\": true,>>"$_tsconfigFile"
 fi
 echo \ \ \"outDir\": \"./dist\",
 echo \ \ \"outDir\": \"./dist\",>>"$_tsconfigFile"
 if [ "$1" == "--root" ]; then
  echo \ \ \"rootDir\": \"./src\",
  echo \ \ \"rootDir\": \"./src\",>>"$_tsconfigFile"
 fi
 if [ "$1" == "--src" ]; then
  echo \ \ \"rootDir\": \"./\",
  echo \ \ \"rootDir\": \"./\",>>"$_tsconfigFile"
 fi
 echo \ \ \"strict\": true,
 echo \ \ \"strict\": true,>>"$_tsconfigFile"
 if [ "$1" == "--root" ]; then
  echo \ \ \"declaration\": false,
  echo \ \ \"declaration\": false,>>"$_tsconfigFile"
 fi
 if [ "$1" == "--src" ]; then
  echo \   \"declaration\": true,
  echo \   \"declaration\": true,>>"$_tsconfigFile"
 fi
 echo \ \ \"skipLibCheck\": true,
 echo \ \ \"skipLibCheck\": true,>>"$_tsconfigFile"
 echo \ \ \"forceConsistentCasingInFileNames\": true
 echo \ \ \"forceConsistentCasingInFileNames\": true>>"$_tsconfigFile"
 echo \ },
 echo \ },>>"$_tsconfigFile"
 echo \ \"include\": [
 echo \ \"include\": [>>"$_tsconfigFile"
 if [ "$1" == "--root" ]; then
  echo \ \ \"src/**/*.ts\"
  echo \ \ \"src/**/*.ts\">>"$_tsconfigFile"
 fi
 if [ "$1" == "--src" ]; then
  echo \ \ \"*.ts\"
  echo \ \ \"*.ts\">>"$_tsconfigFile"
 fi
 echo \ ],
 echo \ ],>>"$_tsconfigFile"
 echo \ \"exclude\": [
 echo \ \"exclude\": [>>"$_tsconfigFile"
 echo \ \ \"node_modules\",
 echo \ \ \"node_modules\",>>"$_tsconfigFile"
 echo \ \ \"dist\"
 echo \ \ \"dist\">>"$_tsconfigFile"
 echo \ ]
 echo \ ]>>"$_tsconfigFile"
 echo }
 echo }>>"$_tsconfigFile"
}

# Create the main.ts file
function _main {
 if [ "$1" == "--stdout" ]; then
   echo & echo Import libraries:
   echo \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
 fi
 cat << IMPORT
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
IMPORT
 if [ "$1" == "--stdout" ]; then
  echo & echo Setting Constant CONFIG variable
  echo \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
 fi
 cat << CONFIG
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

CONFIG

 if [ "$1" == "--stdout" ]; then
  echo & echo Make Support Functions:
  echo \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
 fi
 cat << 'SUPPORT'
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

SUPPORT
 if [ "$1" == "--stdout" ]; then
  echo & echo Define express\(\) in app constant:
  echo \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
 fi
 cat << 'APP'
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
APP
}

# Run the setOauth script to set/reset server id and secret.
function _setEnv {
 _runInstall=0
 if [[ "$1" == "--set" || "$1" == "--secure" && "$_KEYCLOAK_ID" != "" && "$_KEYCLOAK_SECRET" != "" ]]; then
  if [ "$1" == "--set" ]; then
   _runInstall=1
   sed -i "s/<_KEYCLOAK_SERVER_ID_>/$_KEYCLOAK_ID/" "$_curDir/.env"
   sed -i "s/<_KEYCLOAK_SERVER_SECRET_>/$_KEYCLOAK_SECRET/" "$_curDir/.env"
   echo File \'.env\' has set.
  else
   echo Resetting \'.env\' file for Server:
   sed -i "s/$_KEYCLOAK_ID/<_KEYCLOAK_SERVER_ID_>/" "$_curDir/.env"
   sed -i "s/$_KEYCLOAK_SECRET/<_KEYCLOAK_SERVER_SECRET_>/" "$_curDir/.env"
   echo File \'.env\' has been reset.
  fi
 else
  _runInstall=2
  echo Set the _KEYCLOAK_ID and _KEYCLOAK_SECRET variables, then run \`setOauth.sh --set\`
  echo Then run
  echo npm run build
  echo npm run start
 fi
}

# Install and build
function _install {
 echo Installing Dependencies:
 npm install
 echo Building Files to Start Server:
 npm run build
 echo Starting Server:
 npm run start
}

# Switch variable
_optOut=0
function _runBuildExercise {
 if [ "$1" == "--build" ]; then
  echo Creating project, typing with skills like it is the 1980\'s.
  # Call functions
  echo Making \`package.json\` File: && echo
  _packageJson

  echo Creating \`tsconfig.json\` File: && echo
  _tsconfig --root
  _tsconfig --src

  echo Preparing \`main.ts\` File: && echo
  _main --stdout
  _main --src > main.ts

  echo Moving Created Productin file to Server: && echo
  if [ ! -e "$_curDir/src" ]; then
   mkdir "$_curDir/src"
  fi
  mv "$_curDir/main.ts" "$_curDir/src/"

  echo Setting \'.env\' file for Server:
  _setEnv --set

  echo Checking Status of \'.env\' configuration:
  if [ $_runInstall -eq 1 ]; then
   _install
  elif [ $_runInstall -eq 0 ]; then
   _setEnv --next
  fi
 elif [ "$1" == "--secure" ]; then
  _setEnv --secure
 elif [ "$1" == "--reset" ]; then
  echo Resetting Server:
  rm -rf "$_curDir/src/" "$_curDir/dist/" "$_curDir/node_modules/" "$_curDir/package.json" "$_curDir/package-lock.json" "$_curDir/tsconfig.json"
  if [ -e "$_curDir/../../exercise-mcp.code-workspace" ]; then
   if [ -e "$_curDir/../$_ScriptName.sh" ]; then
    sh "$_curDir/../$_ScriptName.sh" --reset-workspace
   fi
  fi
  _setEnv --secure
 else
  _optOut=1
  echo Something unexpected happened
  echo Script only accepts the options:
 fi
}

# Run script main function
if [ "$1" != "" ]; then
 _runBuildExercise $1
else
 _optOut=1
 echo Something unexpected happened
 echo Script requires at least one option:
fi

if [ $_optOut -eq 1 ]; then
 echo \ \ --build
 echo \ \ --reset
 echo \ \ --secure
fi

# Done
echo buildExercise Script Complete:
# Change back to root of exercise-mcp.
cd ../..
