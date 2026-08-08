# Kotlin Weather GUI Server

A variation of [weather-stdio-server](https://github.com/modelcontextprotocol/kotlin-sdk/tree/main/samples/weather-stdio-server) from the
[develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server#kotlin),
focusing on GUI API usage.

> [!IMPORTANT]
> Don't write to stdout, or use `println()`.

## Use With Claude

Build the server first (see [Build Server](#build-server)), then register it.
The tools arrive as `get_alerts`, `get_forecast`, `render_weather`, and
`draw_weather_svg` under the `weather-server-gui` name.

**Claude Code (CLI or VS Code extension)**

Claude Code reads its own MCP config, not the Claude Desktop file:

```batch
claude mcp add --scope user weather-server-gui -- java -jar "D:\Users\name\path\to\weather-server\build\libs\weather-server-0.1.0-all.jar"
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

- Tested on [pilot-matter](https://github.com/isocialPractice/pilot-matter/tree/local-weather)

## Quick Snippets

```
# output
// log to stderr or files, no println()

# project setup
gradle init  # Application, Kotlin

# build
val server = Server(
    Implementation(name = "<server>", version = "1.0.0"),
    ServerOptions(capabilities = ServerCapabilities(tools = ServerCapabilities.Tools(listChanged = true))),
)
```

<details>

<summary>Show Details</summary>

**Code**

```kotlin
// Outputting
///////////////////////////////////////////////////////////////////////////////
// instead of println() use:
System.err.println("Processing:") // writes to stderr

// Minimum Server
///////////////////////////////////////////////////////////////////////////////
fun runMcpServer() {
    val server = Server(
        Implementation(
            name = "Demo",
            version = "1.0.0",
        ),
        ServerOptions(
            capabilities = ServerCapabilities(tools = ServerCapabilities.Tools(listChanged = true)),
        ),
    )

    // register tools on server here

    val transport = StdioServerTransport(
        System.`in`.asSource().buffered(),
        System.out.asSink().buffered(),
    )

    runBlocking {
        val session = server.createSession(transport)
        val done = Job()
        session.onClose {
            done.complete()
        }
        done.join()
    }
}

fun main() = runMcpServer()
```

**Commands**

```batch
:: Project Setup
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
md <server> & cd <server>
gradle init
:: select Application, then Kotlin
gradlew build
```

</details>

## Setup Server Environment

1. Use JDK 11 or higher

```batch
java --version
```

2. Project setup

<CodeGroup>

```bash macOS/Linux
# Create a new directory for our project
mkdir weather
cd weather

# Initialize a new kotlin project
gradle init
```

```batch Windows
:: Create directory
md weather-server
cd weather-server

:: Initialize Kotlin project
gradle init
:: select Application as project type, Kotlin as language

:: Verify the setup
gradlew build
```

</CodeGroup>

## Kotlin MCP Server

The server created in this exercise is a variation of the below files.
<!--START_BUILD-GRADLE-->
```kotlin
// Check latest versions at https://github.com/modelcontextprotocol/kotlin-sdk/releases
val mcpVersion = "0.9.0"
val ktorVersion = "3.2.3"
val slf4jVersion = "2.0.17"

plugins {
    kotlin("jvm") version "2.3.20"
    kotlin("plugin.serialization") version "2.3.20"
    id("com.gradleup.shadow") version "8.3.9"
    application
}

application {
    mainClass.set("MainKt")
}

// The shadow jar carries this version in its file name.
version = "0.1.0"

// The upstream sample inherits its repositories from a parent project, so a
// standalone build has to declare where dependencies resolve from.
repositories {
    mavenCentral()
}

dependencies {
    implementation("io.modelcontextprotocol:kotlin-sdk:$mcpVersion")
    implementation("io.ktor:ktor-client-content-negotiation:$ktorVersion")
    implementation("io.ktor:ktor-serialization-kotlinx-json:$ktorVersion")
    implementation("io.ktor:ktor-client-cio:$ktorVersion")
    implementation("org.slf4j:slf4j-simple:$slf4jVersion")
}
```
<!--END_BUILD-GRADLE-->
### `settings.gradle.kts`
<!--START_SETTINGS-GRADLE-->
```kotlin
rootProject.name = "weather-server"
```
<!--END_SETTINGS-GRADLE-->
### `src/main/kotlin/Main.kt`
<!--START_SERVER-->
```kotlin
// Import dependencies
// The 0.9.x sdk ships its model types in the types package.
import io.modelcontextprotocol.kotlin.sdk.types.CallToolResult
import io.modelcontextprotocol.kotlin.sdk.types.Implementation
import io.modelcontextprotocol.kotlin.sdk.types.ServerCapabilities
import io.modelcontextprotocol.kotlin.sdk.types.TextContent
import io.modelcontextprotocol.kotlin.sdk.types.ToolSchema
import io.modelcontextprotocol.kotlin.sdk.server.Server
import io.modelcontextprotocol.kotlin.sdk.server.ServerOptions
import io.modelcontextprotocol.kotlin.sdk.server.StdioServerTransport
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import kotlinx.io.asSink
import kotlinx.io.asSource
import kotlinx.io.buffered
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import java.time.LocalTime
import java.time.format.DateTimeFormatter

// Constant variables
val LOCAL_TIME_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss")

// Return the current local time, formatted for the GUI render tool.
fun localTime(): String = LocalTime.now().format(LOCAL_TIME_FORMAT)

// The GUI input every gui tool shares: the categorized weather and the local
// time of day.
val guiInputSchema = ToolSchema(
    properties = buildJsonObject {
        putJsonObject("temperature") {
            put("type", "string")
            put("description", "Temperature style, one of hot, medium, cold")
        }
        putJsonObject("precipitation") {
            put("type", "string")
            put("description", "Precipitation style, one of stormy, cloudy, sunny")
        }
        putJsonObject("currentTime") {
            put("type", "string")
            put("description", "Local time of day")
        }
        putJsonObject("repoPath") {
            put("type", "string")
            put("description", "Repository of the GUI application to style")
        }
    },
    required = listOf("temperature", "precipitation", "currentTime"),
)

fun runMcpServer() {
    val server = Server(
        Implementation(
            name = "weather-server",
            version = "0.1.0",
        ),
        ServerOptions(
            capabilities = ServerCapabilities(tools = ServerCapabilities.Tools(listChanged = true)),
        ),
    )

    // Register weather tools

    server.addTool(
        name = "get_alerts",
        description = "Get weather alerts for a US state. Input is a two-letter US state code (e.g. CA, NY)",
        inputSchema = ToolSchema(
            properties = buildJsonObject {
                putJsonObject("state") {
                    put("type", "string")
                    put("description", "Two-letter US state code (e.g. CA, NY)")
                }
            },
            required = listOf("state"),
        ),
    ) { request ->
        val state = request.arguments?.get("state")?.jsonPrimitive?.content
            ?: return@addTool CallToolResult(
                content = listOf(TextContent("The 'state' parameter is required.")),
            )

        val alerts = httpClient.getAlerts(state)
        if (alerts.isEmpty()) {
            return@addTool CallToolResult(
                content = listOf(TextContent("No active alert for the state.")),
            )
        }
        CallToolResult(content = alerts.map { TextContent(it) })
    }

    server.addTool(
        name = "get_forecast",
        description = "Get weather forecast for a location. Note: only US locations are supported by the NWS API.",
        inputSchema = ToolSchema(
            properties = buildJsonObject {
                putJsonObject("latitude") {
                    put("type", "number")
                    put("description", "Latitude of the location")
                }
                putJsonObject("longitude") {
                    put("type", "number")
                    put("description", "Longitude of the location")
                }
            },
            required = listOf("latitude", "longitude"),
        ),
    ) { request ->
        val latitude = request.arguments?.get("latitude")?.jsonPrimitive?.doubleOrNull
        val longitude = request.arguments?.get("longitude")?.jsonPrimitive?.doubleOrNull
        if (latitude == null || longitude == null) {
            return@addTool CallToolResult(
                content = listOf(TextContent("The 'latitude' and 'longitude' parameters are required.")),
            )
        }

        val periods = httpClient.getForecastPeriods(latitude, longitude)
        if (periods.isEmpty()) {
            return@addTool CallToolResult(
                content = listOf(TextContent("No forecast periods available for this location.")),
            )
        }

        val currentForecast = periods.take(5).joinToString("\n---\n") { formatPeriod(it) }
        // The first period is the current one, so the GUI styles from it.
        val renderData = categorizeLocalWeather(periods.first())
        val renderDirectives = renderWeather(renderData, localTime())

        CallToolResult(
            content = listOf(
                TextContent(
                    """
                    |$currentForecast
                    |---
                    |Local Weather: ${formatLocalWeather(renderData)}
                    |$renderDirectives
                    """.trimMargin(),
                ),
            ),
        )
    }

    // renderWeather and drawWeatherSvg are defined in their own files so they
    // stay free of the server instance, so expose them as tools from here.

    server.addTool(
        name = "render_weather",
        description = RENDER_WEATHER_DESCRIPTION,
        inputSchema = guiInputSchema,
    ) { request ->
        val temperature = request.arguments?.get("temperature")?.jsonPrimitive?.content ?: "medium"
        val precipitation = request.arguments?.get("precipitation")?.jsonPrimitive?.content ?: "sunny"
        val currentTime = request.arguments?.get("currentTime")?.jsonPrimitive?.content ?: ""
        val repoPath = request.arguments?.get("repoPath")?.jsonPrimitive?.content

        CallToolResult(
            content = listOf(
                TextContent(renderWeather(LocalWeather(temperature, precipitation), currentTime, repoPath)),
            ),
        )
    }

    server.addTool(
        name = "draw_weather_svg",
        description = DRAW_WEATHER_SVG_DESCRIPTION,
        inputSchema = guiInputSchema,
    ) { request ->
        val temperature = request.arguments?.get("temperature")?.jsonPrimitive?.content ?: "medium"
        val precipitation = request.arguments?.get("precipitation")?.jsonPrimitive?.content ?: "sunny"
        val currentTime = request.arguments?.get("currentTime")?.jsonPrimitive?.content ?: ""

        CallToolResult(
            content = listOf(
                TextContent(drawWeatherSvg(LocalWeather(temperature, precipitation), currentTime)),
            ),
        )
    }

    val transport = StdioServerTransport(
        System.`in`.asSource().buffered(),
        System.out.asSink().buffered(),
    )

    runBlocking {
        val session = server.createSession(transport)
        val done = Job()
        session.onClose {
            done.complete()
        }
        done.join()
    }
}

fun main() = runMcpServer()
```
<!--END_SERVER-->
### `src/main/kotlin/WeatherApi.kt`
<!--START_WEATHER-API-->
```kotlin
// Import dependencies
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.request.get
import io.ktor.client.request.headers
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

val httpClient = HttpClient(CIO) {
    defaultRequest {
        url("https://api.weather.gov")
        headers {
            append("Accept", "application/geo+json")
            append("User-Agent", "weather-app/1.0")
        }
        contentType(ContentType.Application.Json)
    }
    install(ContentNegotiation) {
        json(Json { ignoreUnknownKeys = true })
    }
}

// Extension function to fetch weather alerts for a given state
suspend fun HttpClient.getAlerts(state: String): List<String> {
    val alerts = this.get("/alerts/active/area/${state.uppercase()}").body<AlertsResponse>()
    return alerts.features.map { feature ->
        """
            Event: ${feature.properties.event ?: "Unknown"}
            Area: ${feature.properties.areaDesc ?: "Unknown"}
            Severity: ${feature.properties.severity ?: "Unknown"}
            Description: ${feature.properties.description ?: "No description available"}
            Instruction: ${feature.properties.instruction ?: "No specific instructions provided"}
        """.trimIndent()
    }
}

// Extension function to fetch forecast periods for given latitude and longitude
suspend fun HttpClient.getForecastPeriods(latitude: Double, longitude: Double): List<ForecastPeriod> {
    val points = this.get("/points/$latitude,$longitude").body<PointsResponse>()
    val forecastUrl = points.properties.forecast ?: error("No forecast URL available")
    val forecast = this.get(forecastUrl).body<ForecastResponse>()
    return forecast.properties.periods
}

// Format one forecast period into a readable string.
fun formatPeriod(period: ForecastPeriod): String =
    """
        ${period.name}:
        Temperature: ${period.temperature}°${period.temperatureUnit}
        Wind: ${period.windSpeed} ${period.windDirection}
        Forecast: ${period.detailedForecast ?: period.shortForecast}
    """.trimIndent()

@Serializable
data class PointsResponse(val properties: PointsProperties)

@Serializable
data class PointsProperties(val forecast: String? = null)

@Serializable
data class ForecastResponse(val properties: ForecastProperties)

@Serializable
data class ForecastProperties(val periods: List<ForecastPeriod> = emptyList())

@Serializable
data class ForecastPeriod(
    val name: String? = null,
    val temperature: Int? = null,
    val temperatureUnit: String? = null,
    val windSpeed: String? = null,
    val windDirection: String? = null,
    val shortForecast: String? = null,
    val detailedForecast: String? = null,
    val severity: String? = null,
)

@Serializable
data class AlertsResponse(val features: List<AlertFeature> = emptyList())

@Serializable
data class AlertFeature(val properties: AlertProperties)

@Serializable
data class AlertProperties(
    val event: String? = null,
    val areaDesc: String? = null,
    val severity: String? = null,
    val description: String? = null,
    val instruction: String? = null,
)
```
<!--END_WEATHER-API-->
### `src/main/kotlin/CategorizeLocalWeather.kt`
<!--START_CATEGORIZE-LOCAL-WEATHER-->
```kotlin
// Constant variables
const val HOT_THRESHOLD_F = 80.0
const val COLD_THRESHOLD_F = 32.0
val STORM_TERMS = listOf("thunder", "storm", "squall", "hail", "blizzard", "torrential")
val RAIN_TERMS = listOf("rain", "shower", "drizzle", "snow", "sleet", "freezing", "precipitation")
val CLOUD_TERMS = listOf("cloud", "overcast", "fog", "haze", "mist")
val SEVERE_LEVELS = listOf("high", "severe", "extreme")

// The two styling values the GUI renders from. The categorizer works from the
// typed ForecastPeriod here; the loose key-alias handling of the Python
// variant belongs to its dict input and does not port to data classes.
data class LocalWeather(
    val temperature: String,
    val precipitation: String,
)

// Convert a reported temperature to Fahrenheit, or null when unusable.
private fun toFahrenheit(temperature: Int?, unit: String?): Double? {
    val degrees = temperature?.toDouble() ?: return null
    return if ((unit ?: "F").trim().uppercase().startsWith("C")) {
        degrees * 9.0 / 5.0 + 32.0
    } else {
        degrees
    }
}

// Bucket the reported temperature into hot, cold, or medium.
private fun categorizeTemperature(period: ForecastPeriod): String {
    val degrees = toFahrenheit(period.temperature, period.temperatureUnit) ?: return "medium"
    return when {
        degrees >= HOT_THRESHOLD_F -> "hot"
        degrees < COLD_THRESHOLD_F -> "cold"
        else -> "medium"
    }
}

// Bucket the reported conditions into stormy, cloudy, or sunny.
private fun categorizePrecipitation(period: ForecastPeriod): String {
    val conditions = listOfNotNull(period.detailedForecast, period.shortForecast)
        .joinToString(" ")
        .lowercase()
    val severity = (period.severity ?: "").lowercase()
    val isSevere = severity in SEVERE_LEVELS

    return when {
        STORM_TERMS.any { it in conditions } -> "stormy"
        RAIN_TERMS.any { it in conditions } -> if (isSevere) "stormy" else "cloudy"
        CLOUD_TERMS.any { it in conditions } -> "cloudy"
        else -> "sunny"
    }
}

/**
 * Reduce a forecast period to the two styling values the GUI renders from:
 * temperature as one of hot, medium, cold, and precipitation as one of
 * stormy, cloudy, sunny.
 */
fun categorizeLocalWeather(period: ForecastPeriod): LocalWeather =
    LocalWeather(
        temperature = categorizeTemperature(period),
        precipitation = categorizePrecipitation(period),
    )

// Format categorized weather as a single readable line.
fun formatLocalWeather(localWeather: LocalWeather): String =
    "Temperature: ${localWeather.temperature}, Precipitation: ${localWeather.precipitation}"
```
<!--END_CATEGORIZE-LOCAL-WEATHER-->
### `src/main/kotlin/GuiRenderWeather.kt`
<!--START_GUI-RENDER-WEATHER-->
```kotlin
// Import dependencies
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.Locale

// Constant variables
const val DAY_START_HOUR = 8 // 8AM
const val DAY_END_HOUR = 20  // 8PM
val TIME_FORMATS: List<DateTimeFormatter> = listOf(
    DateTimeFormatter.ofPattern("HH:mm:ss"),
    DateTimeFormatter.ofPattern("HH:mm"),
    DateTimeFormatter.ofPattern("hh:mm:ss a", Locale.US),
    DateTimeFormatter.ofPattern("hh:mm a", Locale.US),
)

// The server owns the Server instance and registers this function as a tool,
// which keeps this file importable from Main.kt without a circular reference.

val RENDER_WEATHER_DESCRIPTION = """
    Render current GUI application based on local weather.
       A. If a file does not exist in repo that is compatible with this
          application, like "local-weather-style/STYLE.md", then:
           1. Determine application architecture
           2. Read styling
              - Analyze current styling
           3. Write to "local-weather-style/STYLE.md" how to update GUI apps
              styling next time this API is called
           4. Recurse to part "B"
       B. Else if the application is a `git` repo:
           1. If branch like "local-weather" exist, then:
              - run: `git checkout local-weather`
              - else run: `git checkout -b local-weather`
           2. Read "local-weather-style/STYLE.md"
           3. Update style according to arguments, and launch GUI
       C. Else:
          1. Do not make style changes
            - Do nothing, and exit

       The repoPath argument, when provided, names the repository of the GUI
       application parts A and B apply to.
""".trimIndent()

// Return the hour of day for a time given as text, or now when unparseable.
fun hourOfDay(currentTime: String): Int {
    val text = currentTime.trim()
    for (timeFormat in TIME_FORMATS) {
        try {
            return LocalTime.parse(text, timeFormat).hour
        } catch (_: DateTimeParseException) {
            // try the next format
        }
    }

    // Unparseable input still has to render something, so fall back to now.
    return LocalTime.now().hour
}

/**
 * Render current GUI application based on local weather.
 *
 * @param localWeather temperature, precipitation
 * @param currentTime local time of day
 */
fun renderWeather(localWeather: LocalWeather, currentTime: String, repoPath: String? = null): String {
    val hour = hourOfDay(currentTime)
    val dayOrNight = if (hour in DAY_START_HOUR until DAY_END_HOUR) "day" else "night"
    val temperatureStyle = localWeather.temperature.ifEmpty { "medium" }
    val precipeStyle = localWeather.precipitation.ifEmpty { "sunny" }
    val repoTarget = if (repoPath.isNullOrEmpty()) "" else "- Apply Styling To Repo: $repoPath\n"

    return """
        |
        |$repoTarget- Render Background: $dayOrNight
        |- Render Tone: $temperatureStyle
        |- Precipitation Use: Set per $precipeStyle
        |- Copy Paste Assets Server Assets:
        |   - Determine GUI Application Context:
        |     - if game-like, then use assets, else do not use assets;
        |     - if game-like:
        |       - if "$precipeStyle" is "cloudy" or "stormy", then use cloud.svg
        |         - if "$temperatureStyle" is "cold", then use snow.svg, else use rain.svg
        |       - else do not use cloud.svg, and style sky blue
        |     - if "$dayOrNight" is "day" use sun.svg, else use moon.svg
        |
    """.trimMargin()
}
```
<!--END_GUI-RENDER-WEATHER-->
### `src/main/kotlin/GuiDrawWeather.kt`
<!--START_GUI-DRAW-WEATHER-->
```kotlin
// Import dependencies
import java.io.File

// Constant variables
// The server runs from the project folder, where assets/ ships.
val ASSETS_DIR: File = File("assets").absoluteFile
const val DAY_ASSET = "sun.svg"
const val NIGHT_ASSET = "moon.svg"
const val CLOUD_ASSET = "cloud.svg"
const val RAIN_ASSET = "rain.svg"
const val SNOW_ASSET = "snow.svg"
val OVERCAST_STYLES = listOf("cloudy", "stormy")

// Stand-in artwork for an asset the server does not ship, so the GUI always has
// something to draw. Deliberately plain, since it only holds the place.
const val MISSING_SVG =
    "<svg id=\"%s\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 360 360\">" +
        "<circle cx=\"180\" cy=\"180\" r=\"160\" fill=\"#d2d2d2\" stroke=\"#000\" stroke-width=\"8\"/>" +
        "<text x=\"180\" y=\"196\" fill=\"#000\" font-family=\"sans-serif\" font-size=\"44\"" +
        " text-anchor=\"middle\">%s</text>" +
        "</svg>"

// The server owns the Server instance and registers this function as a tool,
// which keeps this file importable from Main.kt without a circular reference.

val DRAW_WEATHER_SVG_DESCRIPTION = """
    Draw the SVG set for the current weather, as directives for the GUI app.

    Each asset the server ships is drawn from disk. Any asset it does not
    ship is drawn as a plain stand-in instead, so the draw set is never
    short. When the server ships no asset at all, the directives ask for the
    artwork to be generated rather than copied.
""".trimIndent()

// Return the assets the current weather calls for, in draw order.
private fun drawSet(localWeather: LocalWeather, dayOrNight: String): List<String> {
    val temperatureStyle = localWeather.temperature.ifEmpty { "medium" }
    val precipeStyle = localWeather.precipitation.ifEmpty { "sunny" }

    val drawSet = mutableListOf(if (dayOrNight == "day") DAY_ASSET else NIGHT_ASSET)
    if (precipeStyle in OVERCAST_STYLES) {
        drawSet.add(CLOUD_ASSET)
        drawSet.add(if (temperatureStyle == "cold") SNOW_ASSET else RAIN_ASSET)
    }
    return drawSet
}

// Draw the stand-in markup for an asset the server is missing.
private fun clicheSvg(asset: String): String {
    val name = asset.substringBeforeLast(".")
    return MISSING_SVG.format(name, name.uppercase())
}

/**
 * Draw the SVG set for the current weather, as directives for the GUI app.
 *
 * @param localWeather temperature, precipitation
 * @param currentTime local time of day
 */
fun drawWeatherSvg(localWeather: LocalWeather, currentTime: String): String {
    val hour = hourOfDay(currentTime)
    val dayOrNight = if (hour in DAY_START_HOUR until DAY_END_HOUR) "day" else "night"
    val drawSetAssets = drawSet(localWeather, dayOrNight)

    val available = mutableListOf<String>()
    val missing = mutableListOf<String>()
    for (asset in drawSetAssets) {
        val file = File(ASSETS_DIR, asset)
        if (file.isFile) {
            available.add("   - $asset: ${file.path}")
        } else {
            missing.add("   - $asset:\n     ${clicheSvg(asset)}")
        }
    }

    // Nothing on disk to draw from, so the artwork has to be generated.
    if (available.isEmpty()) {
        return """
            |
            |- Draw SVG Set: ${drawSetAssets.joinToString(", ")}
            |- Generate SVG:
            |   - The server ships no asset for the current weather, so generate one SVG per
            |     name in the draw set
            |   - Match each one to the styling the GUI application already uses
            |   - Keep every viewBox square and the markup self contained, with no external
            |     references
            |
        """.trimMargin()
    }

    val serverPromptOutput = mutableListOf("- Draw SVG Set: ${drawSetAssets.joinToString(", ")}")
    serverPromptOutput.add("- Draw From Server Assets:")
    serverPromptOutput.addAll(available)
    if (missing.isNotEmpty()) {
        serverPromptOutput.add("- Draw Stand-In, Server Ships No Asset:")
        serverPromptOutput.addAll(missing)
    }
    serverPromptOutput.addAll(
        listOf(
            "- Add SVG Tool:",
            "   - For each language the GUI application is written in:",
            "     - Read the application and find the style pattern it already uses",
            "     - Add one lightweight SVG helper built on that style pattern:",
            "       - if the application groups behavior in classes, add a method",
            "       - else add a function",
            "     - The helper takes a name from the draw set and returns its markup",
            "   - Add no dependency, the helper stays lightweight",
        ),
    )

    return "\n" + serverPromptOutput.joinToString("\n") + "\n"
}
```
<!--END_GUI-DRAW-WEATHER-->

## Build Server

The project setup is deliberately different. Instead of one `Main.kt` file,
this server will have:

- Entry: `src/main/kotlin/Main.kt`
- Helper functions:
  - `src/main/kotlin/WeatherApi.kt`
  - `src/main/kotlin/CategorizeLocalWeather.kt`
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
- GUI rendering:
  - `src/main/kotlin/GuiRenderWeather.kt`
  - `src/main/kotlin/GuiDrawWeather.kt`
- GUI Graphics: `assets/`
  - `cloud.svg`
  - `sun.svg`
  - `moon.svg`
  - `rain.svg`
  - `snow.svg`

Build the shadow JAR with `gradlew build`, which writes
`build/libs/weather-server-0.1.0-all.jar`.

## Add Server

**Claude Desktop**

<CodeGroup>

```json macOS/Linux
"weather-server-gui": {
  "command": "java",
  "args": [
    "-jar",
    "/PATH/TO/weather-server/build/libs/weather-server-0.1.0-all.jar"
  ]
}
```

```json Windows
    "weather-server-gui": {
      "command": "java",
      "args": [
        "-jar",
        "D:\\Users\\name\\path\\to\\weather-server\\build\\libs\\weather-server-0.1.0-all.jar"
      ]
    }
```

</CodeGroup>

## Additionally

- [kotlin-sdk](https://github.com/modelcontextprotocol/kotlin-sdk)
