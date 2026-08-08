# TypeScript Weather Client

A variation of
[mcp-client-typescript](https://github.com/modelcontextprotocol/quickstart-resources/tree/main/mcp-client-typescript)
from the [develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-client#typescript),
focusing on usage with the GUI api server variation.

> [!IMPORTANT]
> Don't write to stdout, or use `console.log()` for transport data. The stdio
> transport owns stdout, so log to stderr with `console.error()`.

## Setup Client Environment

<CodeGroup>

```bash macOS/Linux
# Create project directory
mkdir weather-client
cd weather-client

# Initialize npm project
npm init -y

# Install dependencies
npm install @anthropic-ai/sdk @modelcontextprotocol/client dotenv

# Install dev dependencies
npm install -D @types/node typescript

# Create source file
touch index.ts
```

```batch Windows
:: Create project
md weather-client & cd weather-client
npm init -y

:: Install dependencies
npm install @anthropic-ai/sdk @modelcontextprotocol/client dotenv

:: Install dev dependencies
npm install -D @types/node typescript

:: Create source file
new-item index.ts
```

</CodeGroup>

## Set API Key

Use [Anthropic Console](https://platform.claude.com/settings/keys) to get API
key.

**Requires Restart**

> [!NOTE]
> Ensure [Cygwin](https://www.cygwin.com/) dependency is installed, so the build
> script can extract the files below with `sed`.

<CodeGroup>

```bash macOS/Linux
# Add to ~/.bashrc file
vi ~/.bashrc

# Will have a value like "sk-ant-...etc."
export _WEATHER_CLIENT_KEY="<client-api-key>"

# Save and run:
source ~/.bashrc
```

```batch Windows
:: Set variable for reuse
:: Will have a value like "sk-ant-...etc."
setx _WEATHER_CLIENT_KEY "<client-api-key>"
```

</CodeGroup>

## TypeScript MCP Client

### `package.json`
<!--START_PACKAGE-->
```json
{
  "name": "weather-client",
  "version": "1.0.0",
  "description": "A simple MCP client",
  "type": "module",
  "main": "build/index.js",
  "scripts": {
    "build": "tsc"
  },
  "dependencies": {
    "@anthropic-ai/sdk": "^0.68.0",
    "@modelcontextprotocol/client": "^1.20.0",
    "dotenv": "^17.2.3"
  },
  "devDependencies": {
    "@types/node": "^24.7.0",
    "typescript": "^5.9.3"
  }
}
```
<!--END_PACKAGE-->

### `tsconfig.json`
<!--START_TSCONFIG-->
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "types": ["node"],
    "outDir": "./build",
    "rootDir": "./",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["index.ts"],
  "exclude": ["node_modules"]
}
```
<!--END_TSCONFIG-->

### `index.ts`
<!--START_CLIENT-->
```typescript
import { Anthropic } from "@anthropic-ai/sdk";
import {
  MessageParam,
  Tool,
} from "@anthropic-ai/sdk/resources/messages/messages.mjs";
import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";
import readline from "readline/promises";
import dotenv from "dotenv";

dotenv.config(); // load environment variables from .env

const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
if (!ANTHROPIC_API_KEY) {
  throw new Error("ANTHROPIC_API_KEY is not set");
}

const MODEL = "claude-haiku-4-5";
const MAX_TOKENS = 1000;

class MCPClient {
  private mcp: Client;
  private anthropic: Anthropic;
  private transport: StdioClientTransport | null = null;
  private tools: Tool[] = [];

  constructor() {
    this.anthropic = new Anthropic({
      apiKey: ANTHROPIC_API_KEY,
    });
    this.mcp = new Client({ name: "mcp-client-cli", version: "1.0.0" });
  }

  // Launch the server named on the command line and read its tool list.
  async connectToServer(serverScriptPath: string) {
    try {
      const isJs = serverScriptPath.endsWith(".js");
      const isPy = serverScriptPath.endsWith(".py");
      if (!isJs && !isPy) {
        throw new Error("Server script must be a .js or .py file");
      }
      const command = isPy
        ? process.platform === "win32"
          ? "python"
          : "python3"
        : process.execPath;

      this.transport = new StdioClientTransport({
        command,
        args: [serverScriptPath],
      });
      await this.mcp.connect(this.transport);

      const toolsResult = await this.mcp.listTools();
      this.tools = toolsResult.tools.map((tool) => {
        return {
          name: tool.name,
          description: tool.description,
          input_schema: tool.inputSchema,
        };
      });
      console.error(
        "Connected to server with tools:",
        this.tools.map(({ name }) => name)
      );
    } catch (e) {
      console.error("Failed to connect to MCP server: ", e);
      throw e;
    }
  }

  // Send one query to Claude, run any tool it asks for, and let it reply.
  async processQuery(query: string) {
    const messages: MessageParam[] = [
      {
        role: "user",
        content: query,
      },
    ];

    const response = await this.anthropic.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      messages,
      tools: this.tools,
    });

    const finalText = [];

    for (const content of response.content) {
      if (content.type === "text") {
        finalText.push(content.text);
      } else if (content.type === "tool_use") {
        const toolName = content.name;
        const toolArgs = content.input as { [x: string]: unknown } | undefined;

        // The server that owns the tool runs it; the result goes back to Claude.
        const result = await this.mcp.callTool({
          name: toolName,
          arguments: toolArgs,
        });
        finalText.push(
          `[Calling tool ${toolName} with args ${JSON.stringify(toolArgs)}]`
        );

        messages.push({
          role: "user",
          content: result.content
            .filter((block) => block.type === "text")
            .map((block) => block.text)
            .join("\n"),
        });

        const response = await this.anthropic.messages.create({
          model: MODEL,
          max_tokens: MAX_TOKENS,
          messages,
        });

        finalText.push(
          response.content[0].type === "text" ? response.content[0].text : ""
        );
      }
    }

    return finalText.join("\n");
  }

  // Read a line, answer it, repeat until the person types quit.
  async chatLoop() {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    try {
      console.error("\nMCP Client Started!");
      console.error("Type your queries or 'quit' to exit.");

      while (true) {
        const message = await rl.question("\nQuery: ");
        if (message.toLowerCase() === "quit") {
          break;
        }
        const response = await this.processQuery(message);
        console.error("\n" + response);
      }
    } finally {
      rl.close();
    }
  }

  async cleanup() {
    await this.mcp.close();
  }
}

async function main() {
  if (process.argv.length < 3) {
    console.error("Usage: node build/index.js <path_to_server_script>");
    return;
  }
  const mcpClient = new MCPClient();
  try {
    await mcpClient.connectToServer(process.argv[2]);
    await mcpClient.chatLoop();
  } catch (e) {
    console.error("Error:", e);
    await mcpClient.cleanup();
    process.exit(1);
  } finally {
    await mcpClient.cleanup();
    process.exit(0);
  }
}

main();
```
<!--END_CLIENT-->

## Exercise Command

From the client folder, the build script compiles the client and launches it
against the local TypeScript weather server:

```batch
node build\index.js ..\..\..\weather-servers\ts\weather-server\build\index.js
Connected to server with tools: [ 'get_alerts', 'get_forecast', 'render_weather', 'draw_weather_svg' ]

MCP Client Started!
Type your queries or 'quit' to exit.

Query: What are the active weather alerts in California?
```

The client launches the server itself, so the server has to be built first. The
build script builds `develop/weather-servers/ts` when its `build/index.js` is
missing.
