# TypeScript Weather GUI Server

A variation of [weather-server-typescript](https://github.com/modelcontextprotocol/quickstart-resources/tree/main/weather-server-typescript) from the
[develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server#typescript),
focusing on GUI API usage.

> [!IMPORTANT]
> Don't write to stdout, or use `console.log()`.

## Use With Claude

Build the server first (see [Build Server](#build-server)), then register it.
The tools arrive as `get_alerts`, `get_forecast`, `render_weather`, and
`draw_weather_svg` under the `weather-server-gui` name.

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

<!-- - Tested on [vscode-emailClient](https://github.com/isocialPractice/vscode-emailClient/tree/local-weather) -->

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
  ListToolsRequestSchema,
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
