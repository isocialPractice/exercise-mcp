// Import dependencies
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
// Import helpers
import { formatAlerts, formatForecast, moodOf, } from "./broadway.js";
import { ASSETS_DIR, loadSongbook } from "./songbook.js";
// Constant variables
const NWS_API_BASE = "https://api.weather.gov";
const USER_AGENT = "weather-on-broadway/0.1";
const songbook = loadSongbook();
// Initialize server
const server = new Server({
    name: "weather-on-broadway",
    version: "0.1.0",
}, {
    capabilities: {
        tools: {},
    },
});
// Helper function for making NWS API requests
async function makeNWSRequest(url) {
    const headers = {
        "User-Agent": USER_AGENT,
        Accept: "application/geo+json",
    };
    try {
        const response = await fetch(url, { headers });
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return (await response.json());
    }
    catch (error) {
        console.error("Error making NWS request:", error);
        return null;
    }
}
function text(value) {
    return { content: [{ type: "text", text: value }] };
}
server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
        {
            name: "get_forecast",
            description: "Get the weather forecast for a location, staged as an original " +
                "showtune. The current forecast period picks the number: sunny, " +
                "cloudy, stormy, and snowy conditions each land a different song, " +
                "tempo, and chorus from the company songbook.",
            inputSchema: {
                type: "object",
                properties: {
                    latitude: { type: "number", description: "Latitude of the location" },
                    longitude: { type: "number", description: "Longitude of the location" },
                },
                required: ["latitude", "longitude"],
            },
        },
        {
            name: "get_alerts",
            description: "Get active weather alerts for a US state, delivered as the " +
                "company's emergency ensemble number, one scene per alert.",
            inputSchema: {
                type: "object",
                properties: {
                    state: {
                        type: "string",
                        description: "Two-letter US state code (e.g. CA, NY)",
                    },
                },
                required: ["state"],
            },
        },
        {
            name: "get_playbill",
            description: "Get the marquee artwork for a weather mood as inline SVG, with the " +
                "matching showtune title on the board. Also lists the other cliche " +
                "stage assets the server ships (curtain, spotlight, star).",
            inputSchema: {
                type: "object",
                properties: {
                    mood: {
                        type: "string",
                        enum: ["SUNNY", "CLOUDY", "STORMY", "SNOWY", "ALERT"],
                        description: "Which number to bill; defaults to SUNNY",
                    },
                },
            },
        },
    ],
}));
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    if (name === "get_forecast") {
        const { latitude, longitude } = args;
        const pointsUrl = `${NWS_API_BASE}/points/${latitude},${longitude}`;
        const pointsData = await makeNWSRequest(pointsUrl);
        if (!pointsData) {
            return text("The box office reports: no forecast data for this location.");
        }
        const forecastUrl = pointsData.properties?.forecast;
        if (!forecastUrl) {
            return text("The box office reports: no forecast for this location.");
        }
        const forecastData = await makeNWSRequest(forecastUrl);
        const periods = forecastData?.properties?.periods ?? [];
        if (!periods.length) {
            return text("The box office reports: an empty bill for this location.");
        }
        // The current period is the opening number, so it picks the song.
        const song = songbook.get(moodOf(periods[0]));
        if (!song) {
            return text("The songbook is missing tonight's number.");
        }
        return text(formatForecast(periods, song));
    }
    if (name === "get_alerts") {
        const { state } = args;
        const url = `${NWS_API_BASE}/alerts/active/area/${state.toUpperCase()}`;
        const data = await makeNWSRequest(url);
        if (!data || !Array.isArray(data.features)) {
            return text("The box office reports: no alert data for that state.");
        }
        if (!data.features.length) {
            return text("No active alerts - the show goes on as scheduled.");
        }
        const song = songbook.get("ALERT");
        if (!song) {
            return text("The songbook is missing the emergency number.");
        }
        return text(formatAlerts(data.features, song));
    }
    if (name === "get_playbill") {
        const { mood = "SUNNY" } = (args ?? {});
        const song = songbook.get(mood);
        if (!song) {
            return text(`No number is billed for mood "${mood}".`);
        }
        const marquee = readFileSync(join(ASSETS_DIR, "marquee.svg"), "utf8").replace("{title}", song.title);
        const others = ["curtain.svg", "spotlight.svg", "star.svg"]
            .map((asset) => `   - ${join(ASSETS_DIR, asset)}`)
            .join("\n");
        return text(`Tonight's bill: "${song.title}" (${song.tempo})

${marquee}
Other stage assets the server ships:
${others}`);
    }
    throw new Error(`Unknown tool: ${name}`);
});
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("Weather on Broadway MCP Server running on stdio");
}
main().catch((error) => {
    console.error("Fatal error in main():", error);
    process.exit(1);
});
