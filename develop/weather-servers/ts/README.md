# TypeScript Weather GUI Server

A variation of [weather-server-typescript](https://github.com/modelcontextprotocol/quickstart-resources/tree/main/weather-server-typescript) from the
[develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server#typescript),
focusing on GUI API usage.

> [!IMPORTANT]
> Don't write to stdout, or use `console.log()`.

## Use With Claude

Build the server first (see [Build Server](#build-server)), then register it.
The tools arrive as `get_alerts`, `get_forecast`, `render_weather`,
`draw_weather_svg`, and `weather_card` under the `weather-server-gui` name.
On hosts with MCP Apps support, `weather_card` renders an interactive card
inline; everywhere else its plain-text summary shows instead.

**Claude Code (CLI or VS Code extension)**

Claude Code reads its own MCP config, not the Claude Desktop file:

```batch
claude mcp add --scope user weather-server-gui -- node "D:\Users\name\path\to\weather-server\build\index.js"
```

Start a new session, then run `/mcp` to confirm the server connected.

**Claude Desktop**

Add the entry from [Add Server](#add-server) to the `mcpServers` object in
`%APPDATA%\Claude\claude_desktop_config.json`, then fully quit Claude Desktop
from its tray icon and reopen it.

### Example Claude Code Prompt

From a reopository workspace:

```text
Call weather-server-gui at "path/to/server"
render_weather with temperature "hot", precipitation "stormy",
the current time, then carry out the directives it returns - create the
`local-weather-style/STYLE.md` and local-weather branch, and restyle the app
accordingly.
```

- Tested on [vscode-emailClient](https://github.com/isocialPractice/vscode-emailClient)

## Quick Snippets

```
# output
console.error("txt") // no console.log()

# project setup
npm install @modelcontextprotocol/sdk zod

# build
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
const server = new Server({ name: "<server>", version: "1.0.0" }, { capabilities: { tools: {} } });
const transport = new StdioServerTransport();
await server.connect(transport);
```

<details>

<summary>Show Details</summary>

**Code**

```ts
// Outputting
///////////////////////////////////////////////////////////////////////////////
// instead of console.log() use:
console.error("Processing:"); // writes to stderr

// Minimum Server
///////////////////////////////////////////////////////////////////////////////
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

const server = new Server(
  { name: "Demo", version: "1.0.0" },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "add",
      description: "Add two numbers",
      inputSchema: {
        type: "object",
        properties: {
          a: { type: "number", description: "First number" },
          b: { type: "number", description: "Second number" },
        },
        required: ["a", "b"],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  if (name === "add") {
    const { a, b } = args as { a: number; b: number };
    return { content: [{ type: "text", text: String(a + b) }] };
  }
  throw new Error(`Unknown tool: ${name}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

**Commands**

```batch
:: Project Setup
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
md <server> & cd <server>
npm init -y
npm install <dependencies>
npm install -D @types/node typescript
md src
new-item src\index.ts
```

</details>

## Setup Server Environment

1. Use `node` 20 or higher

```batch
node --version
npm --version
```

2. Project setup

<CodeGroup>

```bash macOS/Linux
# Create a new directory for our project
mkdir weather
cd weather

# Initialize a new npm project
npm init -y

# Install dependencies
npm install @modelcontextprotocol/server zod
npm install -D @types/node typescript

# Create our files
mkdir src
touch src/index.ts
```

```batch Windows
:: Create directory
md weather-server
cd weather-server

:: Initialize npm project
npm init -y

:: Dependency installation
npm install @modelcontextprotocol/sdk zod
npm install -D @types/node typescript

:: Server files
md src src\utils src\gui
new-item src\index.ts
```

</CodeGroup>

## TypeScript MCP Server

The server created in this exercise is a variation of the below files.
<!--START_PACKAGE-->
```json
{
  "name": "weather-server",
  "version": "0.1.0",
  "description": "A simple MCP weather server that renders a GUI from local conditions",
  "type": "module",
  "bin": {
    "weather-server": "./build/index.js"
  },
  "scripts": {
    "build": "tsc"
  },
  "files": [
    "build"
  ],
  "dependencies": {
    "@modelcontextprotocol/sdk": "^0.5.0",
    "zod": "^3.24.0"
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
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
```
<!--END_TSCONFIG-->
### `src/index.ts`
<!--START_SERVER-->
```typescript
// Import dependencies
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

// Import helpers
import { makeNWSRequest } from "./utils/makeNwsRequest.js";
import { formatAlert, type AlertFeature } from "./utils/formatAlert.js";
import {
  categorizeLocalWeather,
  formatLocalWeather,
} from "./utils/categorizeLocalWeather.js";
import {
  renderWeather,
  RENDER_WEATHER_DESCRIPTION,
} from "./gui/guiRenderWeather.js";
import {
  drawWeatherSvg,
  DRAW_WEATHER_SVG_DESCRIPTION,
} from "./gui/guiDrawWeather.js";
import {
  weatherCard,
  WEATHER_CARD_DESCRIPTION,
  CARD_CONNECT_DOMAINS,
  CARD_HTML,
  CARD_MIME_TYPE,
  CARD_RESOURCE_URI,
  type WeatherCardArgs,
} from "./gui/guiWeatherCard.js";

// Constant variables
const NWS_API_BASE = "https://api.weather.gov";

// Initialize server
const server = new Server(
  {
    name: "weather-server",
    version: "0.1.0",
  },
  {
    capabilities: {
      tools: {},
      // The weather card ships as a ui:// resource, so the host can list and
      // prefetch it before any tool runs.
      resources: {},
    },
  },
);

// Return the current local time, formatted for the GUI render tool.
function localTime(): string {
  return new Date().toTimeString().slice(0, 8);
}

interface AlertsResponse {
  features: AlertFeature[];
}

interface PointsResponse {
  properties: {
    forecast?: string;
  };
}

interface ForecastPeriod {
  name?: string;
  temperature?: number;
  temperatureUnit?: string;
  windSpeed?: string;
  windDirection?: string;
  detailedForecast?: string;
}

interface ForecastResponse {
  properties: {
    periods: ForecastPeriod[];
  };
}

// renderWeather and drawWeatherSvg are defined in gui/ so those modules stay
// free of the server instance, so expose them as tools from here.
const localWeatherSchema = z.object({
  Temperature: z.string().describe("One of hot, medium, cold"),
  Precipitation: z.string().describe("One of stormy, cloudy, sunny"),
});

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "render_weather",
        description: RENDER_WEATHER_DESCRIPTION,
        inputSchema: {
          type: "object",
          properties: {
            localWeather: {
              type: "object",
              properties: {
                Temperature: { type: "string", description: "One of hot, medium, cold" },
                Precipitation: { type: "string", description: "One of stormy, cloudy, sunny" },
              },
              required: ["Temperature", "Precipitation"],
            },
            currentTime: { type: "string", description: "Local time of day" },
            repoPath: { type: "string", description: "Repository of the GUI application to style" },
          },
          required: ["localWeather", "currentTime"],
        },
      },
      {
        name: "draw_weather_svg",
        description: DRAW_WEATHER_SVG_DESCRIPTION,
        inputSchema: {
          type: "object",
          properties: {
            localWeather: {
              type: "object",
              properties: {
                Temperature: { type: "string", description: "One of hot, medium, cold" },
                Precipitation: { type: "string", description: "One of stormy, cloudy, sunny" },
              },
              required: ["Temperature", "Precipitation"],
            },
            currentTime: { type: "string", description: "Local time of day" },
          },
          required: ["localWeather", "currentTime"],
        },
      },
      {
        name: "weather_card",
        description: WEATHER_CARD_DESCRIPTION,
        inputSchema: {
          type: "object",
          properties: {
            location: {
              type: "string",
              description: 'US place name as "City, ST" (e.g. "Springfield, IL")',
            },
            latitude: {
              type: "number",
              description: "Latitude of an exact point; requires longitude",
              minimum: -90,
              maximum: 90,
            },
            longitude: {
              type: "number",
              description: "Longitude of an exact point; requires latitude",
              minimum: -180,
              maximum: 180,
            },
            days: {
              type: "integer",
              description: "Outlook strip length, 1 collapses the card to current conditions",
              minimum: 1,
              maximum: 8,
              default: 8,
            },
            extraHtml: {
              type: "string",
              description: "Presentational HTML fragment rendered below the weather panel",
            },
          },
        },
        // The tool -> ui:// linkage the host reads to mount the card. Without
        // this stamp the result stays text-only on every host.
        _meta: { ui: { resourceUri: CARD_RESOURCE_URI } },
      },
      {
        name: "get_alerts",
        description: "Get weather alerts for a US state",
        inputSchema: {
          type: "object",
          properties: {
            state: { type: "string", description: "Two-letter US state code (e.g. CA, NY)" },
          },
          required: ["state"],
        },
      },
      {
        name: "get_forecast",
        description: "Get weather forecast for a location",
        inputSchema: {
          type: "object",
          properties: {
            latitude: { type: "number", description: "Latitude of the location", minimum: -90, maximum: 90 },
            longitude: { type: "number", description: "Longitude of the location", minimum: -180, maximum: 180 },
          },
          required: ["latitude", "longitude"],
        },
      },
    ],
  };
});

// The weather card is a ui:// resource the host renders in a sandboxed
// iframe. The connect domains become the iframe's CSP connect-src, so the
// card's fallback fetch reaches exactly those services and nothing else.
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  return {
    resources: [
      {
        uri: CARD_RESOURCE_URI,
        name: "Weather card",
        mimeType: CARD_MIME_TYPE,
        _meta: { ui: { csp: { connectDomains: CARD_CONNECT_DOMAINS } } },
      },
    ],
  };
});

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  if (request.params.uri !== CARD_RESOURCE_URI) {
    throw new Error(`Unknown resource: ${request.params.uri}`);
  }
  return {
    contents: [
      {
        uri: CARD_RESOURCE_URI,
        mimeType: CARD_MIME_TYPE,
        text: CARD_HTML,
        _meta: { ui: { csp: { connectDomains: CARD_CONNECT_DOMAINS } } },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name === "render_weather") {
    const { localWeather, currentTime, repoPath } = args as {
      localWeather: { Temperature: string; Precipitation: string };
      currentTime: string;
      repoPath?: string;
    };
    return {
      content: [
        { type: "text", text: await renderWeather(localWeather, currentTime, repoPath) },
      ],
    };
  }

  if (name === "draw_weather_svg") {
    const { localWeather, currentTime } = args as {
      localWeather: { Temperature: string; Precipitation: string };
      currentTime: string;
    };
    return {
      content: [
        { type: "text", text: await drawWeatherSvg(localWeather, currentTime) },
      ],
    };
  }

  if (name === "weather_card") {
    try {
      const { text, structuredContent } = await weatherCard(
        (args ?? {}) as WeatherCardArgs,
      );
      // structuredContent is what the card paints from; the text keeps the
      // result usable on hosts without MCP Apps support.
      return { content: [{ type: "text", text }], structuredContent };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        content: [
          { type: "text", text: `Unable to render the weather card: ${message}` },
        ],
      };
    }
  }

  if (name === "get_alerts") {
    const { state } = args as { state: string };
    const url = `${NWS_API_BASE}/alerts/active/area/${state.toUpperCase()}`;
    const data = await makeNWSRequest<AlertsResponse>(url);

    if (!data || !("features" in data)) {
      return {
        content: [{ type: "text", text: "Unable to fetch alert or alert not found." }],
      };
    }

    if (!data.features.length) {
      return {
        content: [{ type: "text", text: "No active alert for the state." }],
      };
    }

    const alerts = data.features.map(formatAlert);
    return { content: [{ type: "text", text: alerts.join("\n---\n") }] };
  }

  if (name === "get_forecast") {
    const { latitude, longitude } = args as { latitude: number; longitude: number };
    // forecast grid endpoint
    const pointsUrl = `${NWS_API_BASE}/points/${latitude},${longitude}`;
    const pointsData = await makeNWSRequest<PointsResponse>(pointsUrl);

    if (!pointsData) {
      return {
        content: [
          { type: "text", text: "Unable to fetch forecast data for this location." },
        ],
      };
    }

    // Get the forecast URL from points response
    const forecastUrl = pointsData.properties?.forecast;
    if (!forecastUrl) {
      return {
        content: [
          { type: "text", text: "Unable to fetch detailed forecast for this location." },
        ],
      };
    }

    const forecastData = await makeNWSRequest<ForecastResponse>(forecastUrl);
    if (!forecastData) {
      return {
        content: [
          { type: "text", text: "Unable to fetch detailed forecast for this location." },
        ],
      };
    }

    const periods = forecastData.properties?.periods ?? [];
    if (!periods.length) {
      return {
        content: [
          { type: "text", text: "No forecast periods available for this location." },
        ],
      };
    }

    const forecasts = periods.slice(0, 5).map(
      (period) => `
${period.name}:
Temperature: ${period.temperature}°${period.temperatureUnit}
Wind: ${period.windSpeed} ${period.windDirection}
Forecast: ${period.detailedForecast}
`,
    );

    const currentForecast = forecasts.join("\n---\n");
    // The first period is the current one, so the GUI styles from it.
    const renderData = categorizeLocalWeather(
      periods[0] as Record<string, unknown>,
    );
    const renderDirectives = await renderWeather(renderData, localTime());

    return {
      content: [
        {
          type: "text",
          text: `${currentForecast}
---
Local Weather: ${formatLocalWeather(renderData)}
${renderDirectives}`,
        },
      ],
    };
  }

  throw new Error(`Unknown tool: ${name}`);
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Weather MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error in main():", error);
  process.exit(1);
});
```
<!--END_SERVER-->
### `src/utils/makeNwsRequest.ts`
<!--START_UTILS-MAKE-NWS-REQUEST-->
```typescript
// Constant variables
const USER_AGENT = "weather-app/1.0";

// Helper function for making NWS API requests
export async function makeNWSRequest<T>(url: string): Promise<T | null> {
  const headers = {
    "User-Agent": USER_AGENT,
    Accept: "application/geo+json",
  };

  try {
    const response = await fetch(url, { headers });
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return (await response.json()) as T;
  } catch (error) {
    console.error("Error making NWS request:", error);
    return null;
  }
}
```
<!--END_UTILS-MAKE-NWS-REQUEST-->
### `src/utils/formatAlert.ts`
<!--START_UTILS-FORMAT-ALERT-->
```typescript
export interface AlertFeature {
  properties: {
    event?: string;
    areaDesc?: string;
    severity?: string;
    description?: string;
    instruction?: string;
  };
}

// Format an alert feature into a readable string.
export function formatAlert(feature: AlertFeature): string {
  const props = feature.properties;
  return `
Event: ${props.event || "Unknown"}
Area: ${props.areaDesc || "Unknown"}
Severity: ${props.severity || "Unknown"}
Description: ${props.description || "No description available"}
Instruction: ${props.instruction || "No specific instructions provided"}
`;
}
```
<!--END_UTILS-FORMAT-ALERT-->
### `src/utils/categorizeLocalWeather.ts`
<!--START_CATEGORIZE-LOCAL-WEATHER-->
```typescript
// Constant variables
const HOT_THRESHOLD_F = 80.0;
const COLD_THRESHOLD_F = 32.0;
const STORM_TERMS = ["thunder", "storm", "squall", "hail", "blizzard", "torrential"];
const RAIN_TERMS = ["rain", "shower", "drizzle", "snow", "sleet", "freezing", "precipitation"];
const CLOUD_TERMS = ["cloud", "overcast", "fog", "haze", "mist"];
const SEVERE_LEVELS = ["high", "severe", "extreme"];

// NWS forecast periods and alert properties describe the same conditions under
// different key names, so each lookup below accepts either shape.
const TEMPERATURE_KEYS = ["temperature", "temp"];
const UNIT_KEYS = ["temperatureUnit", "unit"];
const CONDITION_KEYS = ["detailedForecast", "shortForecast", "forecast", "event", "description"];
const SEVERITY_KEYS = ["severity"];

export interface LocalWeather {
  Temperature: string;
  Precipitation: string;
}

// Return the first populated value among keys, matched without case.
function lookup(
  forecast: Record<string, unknown>,
  keys: string[],
  fallback: unknown = "",
): unknown {
  const normalized = new Map(
    Object.entries(forecast).map(([key, value]) => [key.toLowerCase(), value]),
  );
  for (const key of keys) {
    const value = normalized.get(key.toLowerCase());
    if (value !== undefined && value !== null && value !== "") {
      return value;
    }
  }
  return fallback;
}

// Join every populated value among keys into one searchable string.
function collect(forecast: Record<string, unknown>, keys: string[]): string {
  const normalized = new Map(
    Object.entries(forecast).map(([key, value]) => [key.toLowerCase(), value]),
  );
  const found = keys
    .map((key) => normalized.get(key.toLowerCase()))
    .filter((value) => value !== undefined && value !== null && value !== "")
    .map(String);
  return found.join(" ");
}

// Convert a reported temperature to Fahrenheit, or null when unusable.
function toFahrenheit(temperature: unknown, unit: string): number | null {
  const degrees = Number(temperature);
  if (temperature === null || temperature === "" || Number.isNaN(degrees)) {
    return null;
  }

  if (unit.trim().toUpperCase().startsWith("C")) {
    return (degrees * 9.0) / 5.0 + 32.0;
  }
  return degrees;
}

// Bucket the reported temperature into hot, cold, or medium.
function categorizeTemperature(forecast: Record<string, unknown>): string {
  const degrees = toFahrenheit(
    lookup(forecast, TEMPERATURE_KEYS, null),
    String(lookup(forecast, UNIT_KEYS, "F")),
  );

  if (degrees === null) {
    return "medium";
  }
  if (degrees >= HOT_THRESHOLD_F) {
    return "hot";
  }
  if (degrees < COLD_THRESHOLD_F) {
    return "cold";
  }
  return "medium";
}

// Bucket the reported conditions into stormy, cloudy, or sunny.
function categorizePrecipitation(forecast: Record<string, unknown>): string {
  const conditions = collect(forecast, CONDITION_KEYS).toLowerCase();
  const severity = String(lookup(forecast, SEVERITY_KEYS)).toLowerCase();
  const isSevere = SEVERE_LEVELS.includes(severity);

  if (STORM_TERMS.some((term) => conditions.includes(term))) {
    return "stormy";
  }
  if (RAIN_TERMS.some((term) => conditions.includes(term))) {
    return isSevere ? "stormy" : "cloudy";
  }
  if (CLOUD_TERMS.some((term) => conditions.includes(term))) {
    return "cloudy";
  }
  return "sunny";
}

/**
 * Reduce a forecast period to the two styling values the GUI renders from.
 *
 * @param forecast - A NWS forecast period or alert properties mapping
 * @returns Mapping of "Temperature" to one of hot, medium, cold, and
 *          "Precipitation" to one of stormy, cloudy, sunny
 */
export function categorizeLocalWeather(
  forecast: Record<string, unknown>,
): LocalWeather {
  return {
    Temperature: categorizeTemperature(forecast),
    Precipitation: categorizePrecipitation(forecast),
  };
}

// Format categorized weather as a single readable line.
export function formatLocalWeather(localWeather: LocalWeather): string {
  const temperature = localWeather.Temperature || "medium";
  const precipitation = localWeather.Precipitation || "sunny";
  return `Temperature: ${temperature}, Precipitation: ${precipitation}`;
}
```
<!--END_CATEGORIZE-LOCAL-WEATHER-->
### `src/gui/guiRenderWeather.ts`
<!--START_GUI-RENDER-WEATHER-->
```typescript
// Import dependencies
import type { LocalWeather } from "../utils/categorizeLocalWeather.js";

// Constant variables
export const DAY_START_HOUR = 8; // 8AM
export const DAY_END_HOUR = 20; // 8PM
const TIME_PATTERN = /^(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s*([AP])\.?M\.?)?$/i;

// The server owns the McpServer instance and registers this function as a
// tool, which keeps gui/ importable from index.ts without a circular import.

export const RENDER_WEATHER_DESCRIPTION = `Render current GUI application based on local weather.
   A. If a file does not exist in repo that is compatible with this
      application, like "local-weather-style/STYLE.md", then:
       1. Determine application architecture
       2. Read styling
          - Analyze current styling
       3. Write to "local-weather-style/STYLE.md" how to update GUI apps
          styling next time this API is called
       4. Recurse to part "B"
   B. Else if the application is a \`git\` repo:
       1. If branch like "local-weather" exist, then:
          - run: \`git checkout local-weather\`
          - else run: \`git checkout -b local-weather\`
       2. Read "local-weather-style/STYLE.md"
       3. Update style according to arguments, and launch GUI
   C. Else:
      1. Do not make style changes
        - Do nothing, and exit

   The repoPath argument, when provided, names the repository of the GUI
   application parts A and B apply to.`;

// Return the hour of day for a time given as text, or now when unparseable.
export function hourOfDay(currentTime: string): number {
  const match = String(currentTime).trim().match(TIME_PATTERN);
  if (match) {
    let hour = Number(match[1]);
    const meridiem = match[4]?.toUpperCase();
    if (meridiem === "P" && hour < 12) {
      hour += 12;
    }
    if (meridiem === "A" && hour === 12) {
      hour = 0;
    }
    if (hour >= 0 && hour <= 23) {
      return hour;
    }
  }

  // Unparseable input still has to render something, so fall back to now.
  return new Date().getHours();
}

/**
 * Render current GUI application based on local weather.
 *
 * @param localWeather - temperature, precipitation
 * @param currentTime - local time of day
 */
export async function renderWeather(
  localWeather: LocalWeather,
  currentTime: string,
  repoPath?: string,
): Promise<string> {
  const hour = hourOfDay(currentTime);
  const dayOrNight = DAY_START_HOUR <= hour && hour < DAY_END_HOUR ? "day" : "night";
  const temperatureStyle = localWeather.Temperature || "medium";
  const precipeStyle = localWeather.Precipitation || "sunny";
  const repoTarget = repoPath ? `- Apply Styling To Repo: ${repoPath}\n` : "";

  const serverPromptOutput = `
${repoTarget}- Render Background: ${dayOrNight}
- Render Tone: ${temperatureStyle}
- Precipitation Use: Set per ${precipeStyle}
- Copy Paste Assets Server Assets:
   - Determine GUI Application Context:
     - if game-like, then use assets, else do not use assets;
     - if game-like:
       - if "${precipeStyle}" is "cloudy" or "stormy", then use cloud.svg
         - if "${temperatureStyle}" is "cold", then use snow.svg, else use rain.svg
       - else do not use cloud.svg, and style sky blue
     - if "${dayOrNight}" is "day" use sun.svg, else use moon.svg
`;

  return serverPromptOutput;
}
```
<!--END_GUI-RENDER-WEATHER-->
### `src/gui/guiDrawWeather.ts`
<!--START_GUI-DRAW-WEATHER-->
```typescript
// Import dependencies
import { existsSync } from "node:fs";
import { dirname, join, parse, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import type { LocalWeather } from "../utils/categorizeLocalWeather.js";
// Day and night already have one definition in the render module, and both
// modules ship in gui/, so reuse it rather than read the clock twice.
import { DAY_END_HOUR, DAY_START_HOUR, hourOfDay } from "./guiRenderWeather.js";

// Constant variables
// Compiled output runs from build/gui/, so assets/ sits two levels up.
const ASSETS_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "assets");
const DAY_ASSET = "sun.svg";
const NIGHT_ASSET = "moon.svg";
const CLOUD_ASSET = "cloud.svg";
const RAIN_ASSET = "rain.svg";
const SNOW_ASSET = "snow.svg";
const OVERCAST_STYLES = ["cloudy", "stormy"];

// Stand-in artwork for an asset the server does not ship, so the GUI always has
// something to draw. Deliberately plain, since it only holds the place.
const MISSING_SVG =
  '<svg id="{name}" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 360">' +
  '<circle cx="180" cy="180" r="160" fill="#d2d2d2" stroke="#000" stroke-width="8"/>' +
  '<text x="180" y="196" fill="#000" font-family="sans-serif" font-size="44"' +
  ' text-anchor="middle">{label}</text>' +
  "</svg>";

// The server owns the McpServer instance and registers this function as a
// tool, which keeps gui/ importable from index.ts without a circular import.

export const DRAW_WEATHER_SVG_DESCRIPTION = `Draw the SVG set for the current weather, as directives for the GUI app.

   Each asset the server ships is drawn from disk. Any asset it does not
   ship is drawn as a plain stand-in instead, so the draw set is never
   short. When the server ships no asset at all, the directives ask for the
   artwork to be generated rather than copied.`;

// Return the assets the current weather calls for, in draw order.
function drawSet(localWeather: LocalWeather, dayOrNight: string): string[] {
  const temperatureStyle = localWeather.Temperature || "medium";
  const precipeStyle = localWeather.Precipitation || "sunny";

  const assets = [dayOrNight === "day" ? DAY_ASSET : NIGHT_ASSET];
  if (OVERCAST_STYLES.includes(precipeStyle)) {
    assets.push(CLOUD_ASSET);
    assets.push(temperatureStyle === "cold" ? SNOW_ASSET : RAIN_ASSET);
  }
  return assets;
}

// Draw the stand-in markup for an asset the server is missing.
function clicheSvg(asset: string): string {
  const name = parse(asset).name;
  return MISSING_SVG.replace("{name}", name).replace("{label}", name.toUpperCase());
}

/**
 * Draw the SVG set for the current weather, as directives for the GUI app.
 *
 * @param localWeather - temperature, precipitation
 * @param currentTime - local time of day
 */
export async function drawWeatherSvg(
  localWeather: LocalWeather,
  currentTime: string,
): Promise<string> {
  const hour = hourOfDay(currentTime);
  const dayOrNight = DAY_START_HOUR <= hour && hour < DAY_END_HOUR ? "day" : "night";
  const assets = drawSet(localWeather, dayOrNight);

  const available: string[] = [];
  const missing: string[] = [];
  for (const asset of assets) {
    const path = join(ASSETS_DIR, asset);
    if (existsSync(path)) {
      available.push(`   - ${asset}: ${path}`);
    } else {
      missing.push(`   - ${asset}:\n     ${clicheSvg(asset)}`);
    }
  }

  // Nothing on disk to draw from, so the artwork has to be generated.
  if (!available.length) {
    return `
- Draw SVG Set: ${assets.join(", ")}
- Generate SVG:
   - The server ships no asset for the current weather, so generate one SVG per
     name in the draw set
   - Match each one to the styling the GUI application already uses
   - Keep every viewBox square and the markup self contained, with no external
     references
`;
  }

  const serverPromptOutput = [`- Draw SVG Set: ${assets.join(", ")}`];
  serverPromptOutput.push("- Draw From Server Assets:", ...available);
  if (missing.length) {
    serverPromptOutput.push("- Draw Stand-In, Server Ships No Asset:", ...missing);
  }
  serverPromptOutput.push(
    "- Add SVG Tool:",
    "   - For each language the GUI application is written in:",
    "     - Read the application and find the style pattern it already uses",
    "     - Add one lightweight SVG helper built on that style pattern:",
    "       - if the application groups behavior in classes, add a method",
    "       - else add a function",
    "     - The helper takes a name from the draw set and returns its markup",
    "   - Add no dependency, the helper stays lightweight",
  );

  return "\n" + serverPromptOutput.join("\n") + "\n";
}
```
<!--END_GUI-DRAW-WEATHER-->
### `src/gui/guiWeatherCard.ts`
<!--START_GUI-WEATHER-CARD-->
```typescript
// The weather-cards feature: an MCP Apps (SEP-1865) interactive local-weather
// card, ported from the standalone modules/weather_card-py server. The tool
// fetches conditions from the National Weather Service on demand (one request
// per call) and returns a text summary plus the structuredContent payload the
// card paints from; the card itself ships as the ui://weather/card resource
// the host renders in a sandboxed iframe.
//
// Independent by default: no other MCP server, no other tool, no API key.
// Location resolution happens here, first hit wins:
//   1. Explicit latitude + longitude - exact point, no lookup.
//   2. location ("Springfield, IL")  - geocoded here, by name.
//   3. WEATHER_CARD_DEFAULT_LOCATION - the configured home location.
//   4. The host's public IP          - approximate, city-level at best.
// Step 4 is the only one that tells a third party anything, and it only runs
// when the first three are empty. US locations only (NWS is).

// Constant variables
const NWS_API_BASE = "https://api.weather.gov";
// Place name -> coordinates. Keyless, and the only geocoder used here.
const GEOCODE_API = "https://geocoding-api.open-meteo.com/v1/search";
// Last-resort "where am I" when no location is given and none is configured.
const IP_LOCATION_API = "https://ipapi.co/json/";
// Set this in the client config's env block to skip the IP lookup entirely.
const DEFAULT_LOCATION_ENV = "WEATHER_CARD_DEFAULT_LOCATION";
// NWS asks every client to send a descriptive User-Agent with contact info.
const USER_AGENT = "weather-card-app/0.1 (contact@example.com)";

export const CARD_RESOURCE_URI = "ui://weather/card";
// The MCP Apps profile MIME type, so the host can prefetch and
// security-review the card before any tool runs.
export const CARD_MIME_TYPE = "text/html;profile=mcp-app";
// The host turns these into the iframe's CSP connect-src, so the card's
// fallback fetch reaches exactly these services and nothing else.
export const CARD_CONNECT_DOMAINS = [
  "https://api.weather.gov",
  "https://geocoding-api.open-meteo.com",
  "https://ipapi.co",
];

// The server owns the Server instance and registers this module's tool and
// resource, which keeps gui/ importable from index.ts without a circular
// import.

export const WEATHER_CARD_DESCRIPTION = `Show local weather as an interactive card: current conditions plus a
   day-by-day outlook strip, up to 8 days (the default).

   Pass location as "City, ST" (for example "Springfield, IL"). Omit every
   argument to use the caller's own location. Latitude/longitude are an
   escape hatch for a precise point and must be given together.

   days (1-8, default 8) controls the outlook strip: the 8-day forecast is
   on by default, so "render the 8 day forecast" needs no extra arguments.
   days=1 collapses the card to current conditions only. NWS publishes about
   a week ahead, so the strip holds 7-8 entries depending on the time of day.

   For weather asks this card does not cover (hourly detail, active alerts,
   a comparison), fetch what is needed from api.weather.gov and pass a small
   presentational HTML fragment as extraHtml; the card renders it below the
   weather panel (scripts never execute there).

   Self-contained: location resolution and the National Weather Service
   fetch happen inside this tool, one request per call, no background
   polling. US locations only.`;

interface GeocodeMatch {
  name?: string;
  admin1?: string;
  country_code?: string;
  latitude: number;
  longitude: number;
}

interface GeocodeResponse {
  results?: GeocodeMatch[];
}

interface IpLocationResponse {
  latitude?: number | string;
  longitude?: number | string;
  city?: string;
  region?: string;
}

interface CardForecastPeriod {
  name?: string;
  startTime?: string;
  isDaytime?: boolean;
  temperature?: number;
  shortForecast?: string;
  probabilityOfPrecipitation?: { value?: number | null };
}

interface CardPointsResponse {
  properties: {
    forecast?: string;
    relativeLocation?: { properties?: { city?: string; state?: string } };
  };
}

interface CardForecastResponse {
  properties: { periods: CardForecastPeriod[] };
}

interface ResolvedPlace {
  latitude: number;
  longitude: number;
  label: string;
}

interface CardDay {
  day: string;
  high: number;
  precipitationChance: number;
  condition: string;
}

interface CardWeather {
  city: string;
  temperatureF: number;
  precipitationChance: number;
  condition: string;
  shortForecast: string;
  periodName: string;
  days: CardDay[];
}

export interface WeatherCardArgs {
  location?: string;
  latitude?: number;
  longitude?: number;
  days?: number;
  extraHtml?: string;
}

export interface WeatherCardResult {
  text: string;
  structuredContent: Record<string, unknown>;
}

// Fetch JSON, throwing a readable message instead of returning null: the card
// tool reports user-fixable problems (non-US place, bad name) as messages,
// which the null-collapsing makeNWSRequest helper cannot carry.
async function getJson<T>(url: string, accept?: string): Promise<T> {
  const headers: Record<string, string> = { "User-Agent": USER_AGENT };
  if (accept) {
    headers.Accept = accept;
  }
  const response = await fetch(url, { headers });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} from ${url}`);
  }
  return (await response.json()) as T;
}

// Probability of precipitation for a period, defaulting to 0.
function pop(period: CardForecastPeriod): number {
  const value = period.probabilityOfPrecipitation?.value;
  return value === undefined || value === null ? 0 : value;
}

// Map NWS free text ("Partly Cloudy", "Rain Likely") to a card condition.
function classifyCondition(shortForecast: string): string {
  const s = shortForecast.toLowerCase();
  if (/thunder|storm/.test(s)) {
    return "storm";
  }
  if (/snow|sleet|flurr|ice|wintry/.test(s)) {
    return "snow";
  }
  if (/rain|shower|drizzle/.test(s)) {
    return "rain";
  }
  if (/cloud|overcast|fog|haze/.test(s)) {
    return "clouds";
  }
  return "clear";
}

// Split free text into [city, region], repairing a missing comma. The
// geocoder wants "Springfield, IL" and returns nothing at all for
// "Springfield IL", so a bare trailing state code is promoted to a region.
function splitPlace(query: string): [string, string] {
  const text = query.trim().split(/\s+/).join(" ");
  if (text.includes(",")) {
    const at = text.indexOf(",");
    return [text.slice(0, at).trim(), text.slice(at + 1).trim()];
  }
  const at = text.lastIndexOf(" ");
  const head = at > 0 ? text.slice(0, at).trim() : "";
  const tail = at > 0 ? text.slice(at + 1).trim() : "";
  if (head && /^[A-Za-z]{2}$/.test(tail)) {
    return [head, tail];
  }
  return [text, ""];
}

// Resolve a place name to US coordinates. No other server involved.
async function geocode(query: string): Promise<ResolvedPlace> {
  const [city, region] = splitPlace(query);
  const params = new URLSearchParams({
    name: region ? `${city}, ${region}` : city,
    count: "10",
    language: "en",
    format: "json",
  });
  const data = await getJson<GeocodeResponse>(`${GEOCODE_API}?${params}`);
  const matches = data.results ?? [];

  // NWS is US-only, so anything else is a dead end no matter how well it
  // matched.
  const usable = matches.filter((m) => m.country_code === "US");
  if (!usable.length) {
    if (matches.length) {
      throw new Error(
        `"${query}" resolves to ${matches[0].country_code}, and the National ` +
          "Weather Service only covers US locations.",
      );
    }
    throw new Error(
      `No US location found for "${query}". Try a "City, ST" form such as ` +
        `"Springfield, IL".`,
    );
  }

  // Prefer the city itself over near-misses like "Springfield Park".
  const wanted = city.toLowerCase();
  const hit =
    usable.find((m) => (m.name ?? "").toLowerCase() === wanted) ?? usable[0];
  const label = [hit.name, hit.admin1].filter(Boolean).join(", ");
  return { latitude: hit.latitude, longitude: hit.longitude, label };
}

// Approximate the caller's location from the host's public IP. City-level at
// best and often off by a county, so it is the last resort -- set
// WEATHER_CARD_DEFAULT_LOCATION to skip it entirely.
async function locateByIp(): Promise<ResolvedPlace> {
  const data = await getJson<IpLocationResponse>(IP_LOCATION_API);
  const latitude = Number(data.latitude);
  const longitude = Number(data.longitude);
  if (
    data.latitude == null ||
    data.longitude == null ||
    Number.isNaN(latitude) ||
    Number.isNaN(longitude)
  ) {
    throw new Error(
      "Could not determine a location from this network. Pass a location " +
        `such as "Springfield, IL", or set ${DEFAULT_LOCATION_ENV}.`,
    );
  }
  const label = [data.city, data.region].filter(Boolean).join(", ");
  return { latitude, longitude, label };
}

// Turn whatever the caller supplied into coordinates, self-contained:
// explicit coordinates win, then a named location, then the configured
// default, then the public-IP estimate.
async function resolveLocation(
  location: string | undefined,
  latitude: number | undefined,
  longitude: number | undefined,
): Promise<ResolvedPlace> {
  if ((latitude === undefined) !== (longitude === undefined)) {
    throw new Error(
      "latitude and longitude must be given together; pass a location name " +
        "instead to have it looked up.",
    );
  }
  if (latitude !== undefined && longitude !== undefined) {
    return { latitude, longitude, label: "" };
  }
  if (location && location.trim()) {
    return geocode(location);
  }
  const configured = (process.env[DEFAULT_LOCATION_ENV] ?? "").trim();
  if (configured) {
    return geocode(configured);
  }
  return locateByIp();
}

// One /points lookup + one /forecast fetch. Returns the current period plus
// a day-by-day outlook of up to 8 daytime periods.
async function fetchCardWeather(
  latitude: number,
  longitude: number,
): Promise<CardWeather> {
  const headers = { "User-Agent": USER_AGENT, Accept: "application/geo+json" };
  const pointsResponse = await fetch(
    `${NWS_API_BASE}/points/${latitude},${longitude}`,
    { headers },
  );
  if (pointsResponse.status === 404) {
    throw new Error(
      `The National Weather Service has no forecast grid for ` +
        `${latitude},${longitude}. It covers US locations only.`,
    );
  }
  if (!pointsResponse.ok) {
    throw new Error(`HTTP ${pointsResponse.status} from the NWS points endpoint.`);
  }
  const points = ((await pointsResponse.json()) as CardPointsResponse).properties;

  if (!points.forecast) {
    throw new Error("The NWS points response carries no forecast URL for this location.");
  }
  const forecast = await getJson<CardForecastResponse>(
    points.forecast,
    "application/geo+json",
  );
  const periods = forecast.properties.periods ?? [];
  const period = periods[0];
  if (!period) {
    throw new Error("The NWS forecast holds no periods for this location.");
  }

  const relative = points.relativeLocation?.properties ?? {};
  const city = [relative.city, relative.state].filter(Boolean).join(", ");

  // Day-by-day outlook: one entry per daytime period, up to 8. The tool
  // slices this to the number of days the caller actually asked for.
  const days: CardDay[] = [];
  for (const p of periods) {
    if (!p.isDaytime) {
      continue;
    }
    const start = p.startTime ? new Date(p.startTime) : null;
    const label =
      start && !Number.isNaN(start.getTime())
        ? start.toDateString().slice(0, 3)
        : (p.name ?? "").slice(0, 3);
    days.push({
      day: label,
      high: p.temperature ?? 0,
      precipitationChance: pop(p),
      condition: classifyCondition(p.shortForecast ?? ""),
    });
    if (days.length >= 8) {
      break;
    }
  }

  return {
    city,
    temperatureF: period.temperature ?? 0, // US points report Fahrenheit
    precipitationChance: pop(period),
    condition: classifyCondition(period.shortForecast ?? ""),
    shortForecast: period.shortForecast ?? "",
    periodName: period.name ?? "",
    days,
  };
}

/**
 * Fetch conditions for the card and shape the result it paints from.
 *
 * @param args - location, latitude, longitude, days, extraHtml
 * @returns A text summary plus the structuredContent payload; the payload
 *          keys stay snake_case because CARD_HTML reads them by those names
 */
export async function weatherCard(
  args: WeatherCardArgs,
): Promise<WeatherCardResult> {
  const asked = Math.trunc(args.days ?? 8);
  const days = Math.max(1, Math.min(Number.isNaN(asked) ? 8 : asked, 8));

  const place = await resolveLocation(args.location, args.latitude, args.longitude);
  const weather = await fetchCardWeather(place.latitude, place.longitude);

  // The geocoded name is more precise than the NWS station's nearest town.
  if (place.label) {
    weather.city = place.label;
  }
  // The card shows the strip only when more than one day was asked for.
  weather.days = days > 1 ? weather.days.slice(0, days) : [];

  const when = new Date().toTimeString().slice(0, 5);
  const where = weather.city ? `${weather.city} - ` : "";
  let text =
    `${where}${when} - ${Math.round(weather.temperatureF)}°F, ` +
    `${weather.shortForecast}, ${weather.precipitationChance}% chance of ` +
    "precipitation.";
  if (weather.days.length) {
    const outlook = weather.days
      .map((d) => `${d.day} ${Math.round(d.high)}°/${d.precipitationChance}%`)
      .join("; ");
    text += ` Outlook: ${outlook}.`;
  }

  // structuredContent is the only thing the card can paint from, so the
  // snake_case keys here are the card's contract, not a style slip.
  const structuredContent: Record<string, unknown> = {
    text,
    current_time: when,
    local_weather: weather,
  };
  if (args.extraHtml && args.extraHtml.trim()) {
    structuredContent.extra_html = args.extraHtml;
  }
  return { text, structuredContent };
}

// The view: self-contained HTML/JS the host renders in its sandboxed iframe.
// String.raw keeps the inline regex escapes (\s, \S) verbatim; a plain
// template literal would silently strip those backslashes.
export const CARD_HTML = String.raw`
<!doctype html>
<meta charset="utf-8" />
<style>
  /* Defaults are overwritten by hostContext tokens on init, so the card is
     light in a light host and dark in a dark host -- because the HOST says so. */
  :root {
    --fg: #1a1a1a; --muted: #6b7280; --surface: #f3f4f6; --radius: 14px;
    --accent: #3b82f6; --accent-soft: #eff6ff;  /* weather-driven, set in JS */
  }
  * { box-sizing: border-box; }
  body { margin: 0; font: 15px/1.4 system-ui, sans-serif; color: var(--fg); background: transparent; }
  .card {
    background: var(--surface); border-radius: var(--radius); padding: 20px 22px;
    display: grid; gap: 14px;
    border: 1px solid color-mix(in srgb, var(--fg) 8%, transparent);
  }
  .top { display: flex; align-items: baseline; justify-content: space-between; }
  .temp { font-size: 42px; font-weight: 650; letter-spacing: -0.02em; }
  .time { color: var(--muted); font-variant-numeric: tabular-nums; }
  .cond {
    display: inline-flex; align-items: center; gap: 8px;
    background: var(--accent-soft); color: var(--accent);
    padding: 6px 12px; border-radius: 999px; font-weight: 600; width: max-content;
  }
  .dot { width: 9px; height: 9px; border-radius: 50%; background: var(--accent); }
  .precip { color: var(--muted); font-size: 13px; }
  .bar { height: 6px; border-radius: 999px; background: color-mix(in srgb, var(--fg) 10%, transparent); overflow: hidden; }
  .bar > i { display: block; height: 100%; background: var(--accent); width: 0%; transition: width .4s ease; }
  .strip { display: flex; border-top: 1px solid color-mix(in srgb, var(--fg) 8%, transparent); padding-top: 12px; }
  .day { flex: 1; text-align: center; }
  .d { font-size: 12px; color: var(--muted); }
  .h { font-size: 14px; font-weight: 600; margin-top: 4px; }
  .p { font-size: 11px; color: var(--accent); font-weight: 600; margin-top: 4px; }
  .extra { margin-top: 10px; }
</style>

<div class="card" id="card" hidden>
  <div class="top">
    <span class="temp" id="temp">-</span>
    <span class="time" id="time"></span>
  </div>
  <span class="cond"><span class="dot"></span><span id="cond">-</span></span>
  <div>
    <div class="precip"><span id="pct">0</span>% chance of precipitation</div>
    <div class="bar"><i id="fill"></i></div>
  </div>
  <div class="strip" id="strip" hidden></div>
</div>

<!-- Model-extension area: weather_card's optional extraHtml lands here. Set
     via innerHTML, so script tags never execute -- presentational only. -->
<div class="extra" id="extra" hidden></div>

<script type="module">
  // JSON-RPC 2.0 over postMessage -- the same base protocol MCP uses everywhere.
  let id = 0;
  let painted = false;
  let toolArgs = null;   // from ui/notifications/tool-input, if the host sends it
  const pending = new Map();
  const call = (method, params) => new Promise((resolve) => {
    const rid = ++id;
    pending.set(String(rid), resolve);
    parent.postMessage({ jsonrpc: "2.0", id: rid, method, params }, "*");
  });
  const notify = (method, params) =>
    parent.postMessage({ jsonrpc: "2.0", method, params }, "*");

  // Condition -> accent palette. The ONE thing the weather drives is the accent.
  const PALETTE = {
    clear:  { accent: "#f59e0b", soft: "#fffbeb" },
    clouds: { accent: "#64748b", soft: "#f1f5f9" },
    rain:   { accent: "#3b82f6", soft: "#eff6ff" },
    snow:   { accent: "#0ea5e9", soft: "#f0f9ff" },
    storm:  { accent: "#8b5cf6", soft: "#f5f3ff" },
  };

  // hostContext.theme is the string "light" or "dark", not an object of
  // colors. The real design tokens arrive as CSS custom properties under
  // hostContext.styles.variables, so apply those and pick sensible defaults
  // for the handful of tokens this card styles itself.
  function applyTheme(hostContext) {
    if (!hostContext || typeof hostContext !== "object") return;
    const root = document.documentElement.style;
    const vars = (hostContext.styles && hostContext.styles.variables) || {};
    for (const name of Object.keys(vars)) {
      if (typeof vars[name] === "string") root.setProperty(name, vars[name]);
    }
    const dark = hostContext.theme === "dark";
    root.setProperty("--fg", vars["--color-text-primary"] || (dark ? "#f3f4f6" : "#1a1a1a"));
    root.setProperty("--muted", vars["--color-text-secondary"] || (dark ? "#9aa3af" : "#6b7280"));
    root.setProperty("--surface", vars["--color-background-secondary"] || (dark ? "#20242b" : "#f3f4f6"));
  }

  function paint(data) {
    const w = data.local_weather;
    const p = PALETTE[w.condition] || PALETTE.clouds;
    const root = document.documentElement.style;
    root.setProperty("--accent", p.accent);
    root.setProperty("--accent-soft", p.soft);

    document.getElementById("temp").textContent = Math.round(w.temperatureF) + "°";
    document.getElementById("time").textContent =
      (w.city ? w.city + " · " : "") + (data.current_time || "");
    document.getElementById("cond").textContent =
      w.shortForecast || (w.condition.charAt(0).toUpperCase() + w.condition.slice(1));
    document.getElementById("pct").textContent = w.precipitationChance;
    document.getElementById("fill").style.width = w.precipitationChance + "%";

    // Day-by-day outlook strip, shown only when more than one day arrived.
    const strip = document.getElementById("strip");
    const days = w.days || [];
    strip.innerHTML = "";
    strip.hidden = days.length < 2;
    days.forEach((d) => {
      const el = document.createElement("div");
      el.className = "day";
      const dd = document.createElement("div"); dd.className = "d"; dd.textContent = d.day;
      const hh = document.createElement("div"); hh.className = "h";
      hh.textContent = Math.round(d.high) + "°";
      const pp = document.createElement("div"); pp.className = "p";
      pp.textContent = (d.precipitationChance || 0) + "%";
      el.append(dd, hh, pp);
      strip.appendChild(el);
    });

    // Model-extension area. innerHTML never executes script tags, so whatever
    // the model sends stays presentational.
    const extra = document.getElementById("extra");
    if (typeof data.extra_html === "string" && data.extra_html.trim()) {
      extra.innerHTML = data.extra_html;
      extra.hidden = false;
    }

    document.getElementById("card").hidden = false;
    painted = true;
    reportSize();
  }

  function reportSize() {
    // Content drives size; the host follows. The spec asks for both axes.
    notify("ui/notifications/size-changed", {
      width: document.body.scrollWidth,
      height: document.body.scrollHeight,
    });
  }

  // Whatever object carries local_weather is the payload, wherever the host
  // happens to nest it. Guessing one fixed path is how this card ends up an
  // empty box when a host wraps the result differently than expected.
  function extract(node, depth) {
    if (!node || typeof node !== "object" || (depth || 0) > 6) return null;
    if (node.local_weather && typeof node.local_weather === "object") return node;
    for (const key of Object.keys(node)) {
      const found = extract(node[key], (depth || 0) + 1);
      if (found) return found;
    }
    return null;
  }

  window.addEventListener("message", (e) => {
    const msg = e.data;
    if (!msg || typeof msg !== "object") return;
    console.log("[weather-card] rx", msg.method || msg.id || msg);

    // A reply to one of our own calls. Ids are keyed as strings because a host
    // that echoes 1 back as "1" would otherwise never resolve the promise.
    const key = msg.id != null ? String(msg.id) : null;
    if (key !== null && pending.has(key)) {
      pending.get(key)(msg.result);
      pending.delete(key);
      return;
    }

    if (typeof msg.method === "string" && msg.method.indexOf("tool-input") !== -1) {
      // The call's arguments -- kept so the self-fetch fallback below can ask
      // NWS for the same place the tool was asked about.
      toolArgs = (msg.params && (msg.params.arguments || msg.params)) || null;
      return;
    }

    if (typeof msg.method === "string" && /theme|context/i.test(msg.method)) {
      applyTheme((msg.params && msg.params.hostContext) || msg.params);
      return;
    }

    const data = extract(msg);
    if (data) paint(data);
  });

  // The handshake is three steps, and the third is the one that matters: the
  // host withholds ui/notifications/tool-result until the view acknowledges
  // initialization. The acknowledgement is NOT gated on the reply arriving --
  // waiting on a response the host may never send is a deadlock, and the
  // symptom is a mounted card that sits empty forever.
  let announced = false;
  function announceReady() {
    if (announced) return;
    announced = true;
    notify("ui/notifications/initialized", {});
    reportSize();
  }

  (async () => {
    const init = call("ui/initialize", {
      appCapabilities: { availableDisplayModes: ["inline", "fullscreen"] },
    });
    setTimeout(announceReady, 600);
    const result = await init;
    applyTheme(result && result.hostContext);
    announceReady();

    // Some hosts hand the result back on the init response instead.
    const data = extract(result);
    if (data) paint(data);
  })();

  // ------------------------------------------------------------------------
  // Independence fallback. If the host never delivers the tool result, the
  // card fetches the same NWS data itself -- once, on render, no timer loop.
  // The resource declares these hosts in its CSP connect domains, so the
  // sandbox allows exactly these calls and nothing else. Location comes from
  // the tool-input arguments when the host sent them, else the public IP.
  // ------------------------------------------------------------------------
  function classify(s) {
    s = (s || "").toLowerCase();
    if (/thunder|storm/.test(s)) return "storm";
    if (/snow|sleet|flurr|ice|wintry/.test(s)) return "snow";
    if (/rain|shower|drizzle/.test(s)) return "rain";
    if (/cloud|overcast|fog|haze/.test(s)) return "clouds";
    return "clear";
  }

  async function getJSON(url) {
    const r = await fetch(url);
    if (!r.ok) throw new Error(url + " -> " + r.status);
    return r.json();
  }
  async function selfFetch() {
    try {
      let lat = toolArgs && toolArgs.latitude;
      let lon = toolArgs && toolArgs.longitude;
      let label = "";

      if ((lat == null || lon == null) && toolArgs && toolArgs.location) {
        // Same comma repair as the server: "Springfield IL" -> "Springfield, IL".
        let q = String(toolArgs.location).trim().replace(/\s+/g, " ");
        if (!q.includes(",")) q = q.replace(/^(.*\S)\s+([A-Za-z]{2})$/, "$1, $2");
        const geo = await getJSON(
          "https://geocoding-api.open-meteo.com/v1/search?name=" +
          encodeURIComponent(q) + "&count=5&language=en&format=json"
        );
        const hit = ((geo.results || []).filter((r) => r.country_code === "US"))[0];
        if (hit) {
          lat = hit.latitude; lon = hit.longitude;
          label = [hit.name, hit.admin1].filter(Boolean).join(", ");
        }
      }

      if (lat == null || lon == null) {
        const ip = await getJSON("https://ipapi.co/json/");
        lat = ip.latitude; lon = ip.longitude;
        label = [ip.city, ip.region].filter(Boolean).join(", ");
      }
      if (lat == null || lon == null) return;

      const pts = await getJSON("https://api.weather.gov/points/" + lat + "," + lon);
      const fc = await getJSON(pts.properties.forecast);
      const periods = fc.properties.periods || [];
      const p = periods[0];

      // Honor the outlook the tool was asked for, mirroring the server's
      // default: 8 days unless the call explicitly narrowed it.
      const wanted = Math.max(1, Math.min((toolArgs && toolArgs.days) || 8, 8));
      const days = [];
      for (const d of periods) {
        if (!d.isDaytime) continue;
        days.push({
          day: new Date(d.startTime).toDateString().slice(0, 3),
          high: d.temperature,
          precipitationChance: ((d.probabilityOfPrecipitation || {}).value) || 0,
          condition: classify(d.shortForecast),
        });
        if (days.length >= wanted) break;
      }

      if (painted) return; // the host's push won the race; keep its data
      paint({
        current_time: new Date().toTimeString().slice(0, 5),
        local_weather: {
          city: label,
          temperatureF: p.temperature,
          precipitationChance: ((p.probabilityOfPrecipitation || {}).value) || 0,
          condition: classify(p.shortForecast),
          shortForecast: p.shortForecast || "",
          days: wanted > 1 ? days : [],
        },
      });
    } catch (err) {
      console.log("[weather-card] self-fetch failed", String(err));
    }
  }

  setTimeout(() => { if (!painted) selfFetch(); }, 2500);
</script>
`;
```
<!--END_GUI-WEATHER-CARD-->

## Build Server

The project setup is deliberately different. Instead of one `src/index.ts` file,
this server will have:

- Entry: `src/index.ts`
- Helper functions: `src/utils/`
  - `makeNwsRequest.ts`
  - `formatAlert.ts`
  - `categorizeLocalWeather.ts`
    - Summary: for GUI instance of server, so weather will change display according to:
      - Hot, Medium, or Cold
        - Cold: **temp. < 32°F(0°C)**
        - Medium: **temp. > `cold` && temp. < 80°F(26.67°C)**
        - Hot: **temp. >= 80°F(26.67°C)**
        - Each determines effect for `["stormy", "cloudy", "sunny"]`
      - Stormy, Cloudy, or Sunny
        - If stormy or cloudy, then:
          - If stormy, then more precipitation; else less precipitation
          - If cold, then snow; else rain
          - If medium or hot, then:
            - Medium: more gray toned
            - Hot: more dark toned
- GUI rendering: `src/gui/`
  - `guiRenderWeather.ts`
  - `guiDrawWeather.ts`
  - `guiWeatherCard.ts`
    - Summary: the weather-cards feature, ported from
      `modules/weather_card-py` -- the `weather_card` tool resolves a
      location (name, coordinates, configured default, or public IP),
      fetches current conditions plus a day-by-day outlook from NWS, and
      returns a text summary with the `structuredContent` payload the
      interactive `ui://weather/card` resource paints from
- GUI Graphics: `assets/`
  - `cloud.svg`
  - `sun.svg`
  - `moon.svg`
  - `rain.svg`
  - `snow.svg`

Build with `npm run build` before connecting a client.

## Add Server

**Claude Desktop**

<CodeGroup>

```json macOS/Linux
"weather-server-gui": {
  "command": "node",
  "args": ["/PATH/TO/weather-server/build/index.js"]
}
```

```json Windows
    "weather-server-gui": {
      "command": "node",
      "args": [
        "D:\\Users\\name\\path\\to\\weather-server\\build\\index.js"
      ]
    }
```

</CodeGroup>

## Additionally

- [typescript-sdk](https://github.com/modelcontextprotocol/typescript-sdk)
