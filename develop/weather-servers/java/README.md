# Java Weather GUI Server

A variation of [starter-stdio-server](https://github.com/spring-projects/spring-ai-examples/tree/main/model-context-protocol/weather/starter-stdio-server) from the
[develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server#java),
focusing on GUI API usage.

> [!IMPORTANT]
> Don't write to stdout, or use `System.out.println()`. Keep the Spring banner
> and console logging off.

## Use With Claude

Build the server first (see [Build Server](#build-server)), then register it.
The tools arrive as `getAlerts`, `getForecast`, `renderWeather`, and
`drawWeatherSvg` under the `weather-server-gui` name.

**Claude Code (CLI or VS Code extension)**

Claude Code reads its own MCP config, not the Claude Desktop file:

```batch
claude mcp add --scope user weather-server-gui -- java -Dspring.ai.mcp.server.transport=STDIO -jar "D:\Users\name\path\to\weather-server\target\weather-server-0.0.1-SNAPSHOT.jar"
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

- Tested on [esp32-fetch-data](https://github.com/jhauga/esp32-fetch-data/tree/local-weather)

## Quick Snippets

```
# output
// log to stderr or files, no System.out.println()

# project setup (application.properties)
spring.main.bannerMode=off
logging.pattern.console=

# build
@Bean
public ToolCallbackProvider weatherTools(WeatherService weatherService) {
    return MethodToolCallbackProvider.builder().toolObjects(weatherService).build();
}
```

<details>

<summary>Show Details</summary>

**Code**

```java
// Minimum Server
///////////////////////////////////////////////////////////////////////////////
@SpringBootApplication
public class McpServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(McpServerApplication.class, args);
    }

    @Bean
    public ToolCallbackProvider tools(DemoService demoService) {
        return MethodToolCallbackProvider.builder().toolObjects(demoService).build();
    }
}

@Service
class DemoService {

    @Tool(description = "Add two numbers")
    public int add(int a, int b) {
        return a + b;
    }
}
```

**Commands**

```batch
:: Project Setup
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Bootstrap with the Spring Initializer: https://start.spring.io/
:: Add spring-ai-starter-mcp-server and spring-web dependencies
mvnw clean install
```

</details>

## Setup Server Environment

1. Use `java` 17 or higher, with Spring Boot 3.3.x or higher

```batch
java --version
```

2. Project setup

Bootstrap the project with the [Spring Initializer](https://start.spring.io/),
adding the dependencies:

<CodeGroup>

```xml Maven
<dependencies>
      <dependency>
          <groupId>org.springframework.ai</groupId>
          <artifactId>spring-ai-starter-mcp-server</artifactId>
      </dependency>

      <dependency>
          <groupId>org.springframework</groupId>
          <artifactId>spring-web</artifactId>
      </dependency>
</dependencies>
```

```groovy Gradle
dependencies {
  implementation platform("org.springframework.ai:spring-ai-starter-mcp-server")
  implementation platform("org.springframework:spring-web")
}
```

```xml Windows
<dependencies>
      <dependency>
          <groupId>org.springframework.ai</groupId>
          <artifactId>spring-ai-starter-mcp-server</artifactId>
      </dependency>

      <dependency>
          <groupId>org.springframework</groupId>
          <artifactId>spring-web</artifactId>
      </dependency>
</dependencies>
```

</CodeGroup>

## Java MCP Server

The server created in this exercise is a variation of the below files.
<!--START_POM-->
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.4.5</version>
    <relativePath/>
  </parent>

  <groupId>org.example</groupId>
  <artifactId>weather-server</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <description>A simple MCP weather server that renders a GUI from local conditions</description>

  <properties>
    <java.version>17</java.version>
    <spring-ai.version>1.0.0</spring-ai.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.springframework.ai</groupId>
      <artifactId>spring-ai-starter-mcp-server</artifactId>
    </dependency>

    <dependency>
      <groupId>org.springframework</groupId>
      <artifactId>spring-web</artifactId>
    </dependency>
  </dependencies>

  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>org.springframework.ai</groupId>
        <artifactId>spring-ai-bom</artifactId>
        <version>${spring-ai.version}</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
```
<!--END_POM-->
### `src/main/resources/application.properties`
<!--START_APPLICATION-PROPERTIES-->
```properties
spring.main.bannerMode=off
logging.pattern.console=
```
<!--END_APPLICATION-PROPERTIES-->
### `McpServerApplication.java`
<!--START_SERVER-->
```java
// Import dependencies
package org.example.weatherserver;

import org.springframework.ai.tool.ToolCallbackProvider;
import org.springframework.ai.tool.method.MethodToolCallbackProvider;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

// Import helpers
import org.example.weatherserver.gui.GuiRenderWeather;
import org.example.weatherserver.gui.GuiDrawWeather;

@SpringBootApplication
public class McpServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(McpServerApplication.class, args);
    }

    // The gui services stay free of the MCP wiring, so their tools register
    // here beside the weather service.
    @Bean
    public ToolCallbackProvider weatherTools(
            WeatherService weatherService,
            GuiRenderWeather guiRenderWeather,
            GuiDrawWeather guiDrawWeather) {
        return MethodToolCallbackProvider.builder()
            .toolObjects(weatherService, guiRenderWeather, guiDrawWeather)
            .build();
    }
}
```
<!--END_SERVER-->
### `WeatherService.java`
<!--START_WEATHER-SERVICE-->
```java
// Import dependencies
package org.example.weatherserver;

import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Service;

// Import helpers
import org.example.weatherserver.gui.GuiRenderWeather;
import org.example.weatherserver.utils.CategorizeLocalWeather;
import org.example.weatherserver.utils.CategorizeLocalWeather.LocalWeather;
import org.example.weatherserver.utils.FormatAlert;
import org.example.weatherserver.utils.NwsClient;

@Service
public class WeatherService {

    // Constant variables
    private static final DateTimeFormatter LOCAL_TIME_FORMAT =
        DateTimeFormatter.ofPattern("HH:mm:ss");

    private final NwsClient nwsClient;
    private final GuiRenderWeather guiRenderWeather;

    public WeatherService(NwsClient nwsClient, GuiRenderWeather guiRenderWeather) {
        this.nwsClient = nwsClient;
        this.guiRenderWeather = guiRenderWeather;
    }

    // Return the current local time, formatted for the GUI render tool.
    private String localTime() {
        return LocalTime.now().format(LOCAL_TIME_FORMAT);
    }

    @Tool(description = "Get weather alerts for a US state")
    public String getAlerts(
            @ToolParam(description = "Two-letter US state code (e.g. CA, NY)") String state) {
        JsonNode data = nwsClient.makeNwsRequest("/alerts/active/area/" + state.toUpperCase());

        if (data == null || !data.has("features")) {
            return "Unable to fetch alert or alert not found.";
        }

        JsonNode features = data.get("features");
        if (features.isEmpty()) {
            return "No active alert for the state.";
        }

        List<String> alerts = new ArrayList<>();
        for (JsonNode feature : features) {
            alerts.add(FormatAlert.format(feature));
        }
        return String.join("\n---\n", alerts);
    }

    @Tool(description = "Get weather forecast for a location")
    public String getForecast(
            @ToolParam(description = "Latitude of the location") double latitude,
            @ToolParam(description = "Longitude of the location") double longitude) {
        // forecast grid endpoint
        JsonNode pointsData = nwsClient.makeNwsRequest("/points/" + latitude + "," + longitude);

        if (pointsData == null) {
            return "Unable to fetch forecast data for this location.";
        }

        // Get the forecast URL from points response
        JsonNode forecastUrl = pointsData.path("properties").path("forecast");
        if (!forecastUrl.isTextual()) {
            return "Unable to fetch detailed forecast for this location.";
        }

        JsonNode forecastData = nwsClient.makeNwsRequest(forecastUrl.asText());
        if (forecastData == null) {
            return "Unable to fetch detailed forecast for this location.";
        }

        JsonNode periods = forecastData.path("properties").path("periods");
        if (!periods.isArray() || periods.isEmpty()) {
            return "No forecast periods available for this location.";
        }

        List<String> forecasts = new ArrayList<>();
        for (int i = 0; i < Math.min(5, periods.size()); i++) { // next 5 periods
            JsonNode period = periods.get(i);
            forecasts.add("""

                %s:
                Temperature: %d°%s
                Wind: %s %s
                Forecast: %s
                """.formatted(
                period.path("name").asText(),
                period.path("temperature").asInt(),
                period.path("temperatureUnit").asText(),
                period.path("windSpeed").asText(),
                period.path("windDirection").asText(),
                period.path("detailedForecast").asText()));
        }

        String currentForecast = String.join("\n---\n", forecasts);
        // The first period is the current one, so the GUI styles from it.
        LocalWeather renderData = CategorizeLocalWeather.categorize(periods.get(0));
        String renderDirectives = guiRenderWeather.render(renderData, localTime());

        return """
            %s
            ---
            Local Weather: %s
            %s""".formatted(
            currentForecast,
            CategorizeLocalWeather.formatLocalWeather(renderData),
            renderDirectives);
    }
}
```
<!--END_WEATHER-SERVICE-->
### `utils/NwsClient.java`
<!--START_UTILS-MAKE-NWS-REQUEST-->
```java
// Import dependencies
package org.example.weatherserver.utils;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class NwsClient {

    // Constant variables
    private static final String NWS_API_BASE = "https://api.weather.gov";
    private static final String USER_AGENT = "weather-app/1.0";

    private final RestClient restClient;

    public NwsClient() {
        this.restClient = RestClient.builder()
            .baseUrl(NWS_API_BASE)
            .defaultHeader("Accept", "application/geo+json")
            .defaultHeader("User-Agent", USER_AGENT)
            .build();
    }

    /** Make a request to the NWS API with proper error handling. */
    public JsonNode makeNwsRequest(String uri) {
        try {
            return restClient.get()
                .uri(uri)
                .retrieve()
                .body(JsonNode.class);
        }
        catch (Exception e) {
            return null;
        }
    }
}
```
<!--END_UTILS-MAKE-NWS-REQUEST-->
### `utils/FormatAlert.java`
<!--START_UTILS-FORMAT-ALERT-->
```java
// Import dependencies
package org.example.weatherserver.utils;

import com.fasterxml.jackson.databind.JsonNode;

public final class FormatAlert {

    private FormatAlert() {
    }

    private static String read(JsonNode props, String key, String fallback) {
        JsonNode value = props.path(key);
        return value.isTextual() && !value.asText().isEmpty() ? value.asText() : fallback;
    }

    /** Format an alert feature into a readable string. */
    public static String format(JsonNode feature) {
        JsonNode props = feature.path("properties");
        return """

            Event: %s
            Area: %s
            Severity: %s
            Description: %s
            Instruction: %s
            """.formatted(
            read(props, "event", "Unknown"),
            read(props, "areaDesc", "Unknown"),
            read(props, "severity", "Unknown"),
            read(props, "description", "No description available"),
            read(props, "instruction", "No specific instructions provided"));
    }
}
```
<!--END_UTILS-FORMAT-ALERT-->
### `utils/CategorizeLocalWeather.java`
<!--START_CATEGORIZE-LOCAL-WEATHER-->
```java
// Import dependencies
package org.example.weatherserver.utils;

import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import com.fasterxml.jackson.databind.JsonNode;

public final class CategorizeLocalWeather {

    // Constant variables
    private static final double HOT_THRESHOLD_F = 80.0;
    private static final double COLD_THRESHOLD_F = 32.0;
    private static final List<String> STORM_TERMS =
        List.of("thunder", "storm", "squall", "hail", "blizzard", "torrential");
    private static final List<String> RAIN_TERMS =
        List.of("rain", "shower", "drizzle", "snow", "sleet", "freezing", "precipitation");
    private static final List<String> CLOUD_TERMS =
        List.of("cloud", "overcast", "fog", "haze", "mist");
    private static final List<String> SEVERE_LEVELS = List.of("high", "severe", "extreme");

    // NWS forecast periods and alert properties describe the same conditions
    // under different key names, so each lookup below accepts either shape.
    private static final List<String> TEMPERATURE_KEYS = List.of("temperature", "temp");
    private static final List<String> UNIT_KEYS = List.of("temperatureUnit", "unit");
    private static final List<String> CONDITION_KEYS =
        List.of("detailedForecast", "shortForecast", "forecast", "event", "description");
    private static final List<String> SEVERITY_KEYS = List.of("severity");

    /** The two styling values the GUI renders from. */
    public record LocalWeather(String temperature, String precipitation) {
    }

    private CategorizeLocalWeather() {
    }

    private static Map<String, JsonNode> normalized(JsonNode forecast) {
        Map<String, JsonNode> normalized = new LinkedHashMap<>();
        Iterator<String> names = forecast.fieldNames();
        while (names.hasNext()) {
            String name = names.next();
            normalized.put(name.toLowerCase(Locale.ROOT), forecast.get(name));
        }
        return normalized;
    }

    /** Return the first populated value among keys, matched without case. */
    private static String lookup(JsonNode forecast, List<String> keys, String fallback) {
        Map<String, JsonNode> fields = normalized(forecast);
        for (String key : keys) {
            JsonNode value = fields.get(key.toLowerCase(Locale.ROOT));
            if (value != null && !value.isNull() && !value.asText().isEmpty()) {
                return value.asText();
            }
        }
        return fallback;
    }

    /** Join every populated value among keys into one searchable string. */
    private static String collect(JsonNode forecast, List<String> keys) {
        StringBuilder found = new StringBuilder();
        for (String key : keys) {
            String value = lookup(forecast, List.of(key), "");
            if (!value.isEmpty()) {
                if (found.length() > 0) {
                    found.append(" ");
                }
                found.append(value);
            }
        }
        return found.toString();
    }

    /** Convert a reported temperature to Fahrenheit, or null when unusable. */
    private static Double toFahrenheit(String temperature, String unit) {
        double degrees;
        try {
            degrees = Double.parseDouble(temperature);
        }
        catch (NumberFormatException e) {
            return null;
        }

        if (unit.trim().toUpperCase(Locale.ROOT).startsWith("C")) {
            return degrees * 9.0 / 5.0 + 32.0;
        }
        return degrees;
    }

    /** Bucket the reported temperature into hot, cold, or medium. */
    private static String categorizeTemperature(JsonNode forecast) {
        Double degrees = toFahrenheit(
            lookup(forecast, TEMPERATURE_KEYS, ""),
            lookup(forecast, UNIT_KEYS, "F"));

        if (degrees == null) {
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

    /** Bucket the reported conditions into stormy, cloudy, or sunny. */
    private static String categorizePrecipitation(JsonNode forecast) {
        String conditions = collect(forecast, CONDITION_KEYS).toLowerCase(Locale.ROOT);
        String severity = lookup(forecast, SEVERITY_KEYS, "").toLowerCase(Locale.ROOT);
        boolean isSevere = SEVERE_LEVELS.contains(severity);

        if (STORM_TERMS.stream().anyMatch(conditions::contains)) {
            return "stormy";
        }
        if (RAIN_TERMS.stream().anyMatch(conditions::contains)) {
            return isSevere ? "stormy" : "cloudy";
        }
        if (CLOUD_TERMS.stream().anyMatch(conditions::contains)) {
            return "cloudy";
        }
        return "sunny";
    }

    /**
     * Reduce a forecast period to the two styling values the GUI renders from:
     * temperature as one of hot, medium, cold, and precipitation as one of
     * stormy, cloudy, sunny.
     */
    public static LocalWeather categorize(JsonNode forecast) {
        return new LocalWeather(
            categorizeTemperature(forecast),
            categorizePrecipitation(forecast));
    }

    /** Format categorized weather as a single readable line. */
    public static String formatLocalWeather(LocalWeather localWeather) {
        return "Temperature: %s, Precipitation: %s".formatted(
            localWeather.temperature(), localWeather.precipitation());
    }
}
```
<!--END_CATEGORIZE-LOCAL-WEATHER-->
### `gui/GuiRenderWeather.java`
<!--START_GUI-RENDER-WEATHER-->
```java
// Import dependencies
package org.example.weatherserver.gui;

import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Locale;

import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Service;

// Import helpers
import org.example.weatherserver.utils.CategorizeLocalWeather.LocalWeather;

// The application wires this service into the tool callback provider, which
// keeps gui/ free of the MCP plumbing.
@Service
public class GuiRenderWeather {

    // Constant variables
    static final int DAY_START_HOUR = 8; // 8AM
    static final int DAY_END_HOUR = 20;  // 8PM
    private static final List<DateTimeFormatter> TIME_FORMATS = List.of(
        DateTimeFormatter.ofPattern("HH:mm:ss"),
        DateTimeFormatter.ofPattern("HH:mm"),
        DateTimeFormatter.ofPattern("hh:mm:ss a", Locale.US),
        DateTimeFormatter.ofPattern("hh:mm a", Locale.US));

    /** Return the hour of day for a time given as text, or now when unparseable. */
    static int hourOfDay(String currentTime) {
        String text = currentTime.trim();
        for (DateTimeFormatter timeFormat : TIME_FORMATS) {
            try {
                return LocalTime.parse(text, timeFormat).getHour();
            }
            catch (DateTimeParseException e) {
                // try the next format
            }
        }

        // Unparseable input still has to render something, so fall back to now.
        return LocalTime.now().getHour();
    }

    static String styleOr(String style, String fallback) {
        return style == null || style.isEmpty() ? fallback : style;
    }

    @Tool(description = """
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

           The repoPath argument, when provided, names the repository of the
           GUI application parts A and B apply to.
        """)
    public String renderWeather(
            @ToolParam(description = "Temperature style, one of hot, medium, cold") String temperature,
            @ToolParam(description = "Precipitation style, one of stormy, cloudy, sunny") String precipitation,
            @ToolParam(description = "Local time of day") String currentTime,
            @ToolParam(required = false, description = "Repository of the GUI application to style") String repoPath) {
        return render(new LocalWeather(temperature, precipitation), currentTime, repoPath);
    }

    /** Render current GUI application based on local weather. */
    public String render(LocalWeather localWeather, String currentTime) {
        return render(localWeather, currentTime, null);
    }

    /** Render current GUI application based on local weather. */
    public String render(LocalWeather localWeather, String currentTime, String repoPath) {
        int hour = hourOfDay(currentTime);
        String dayOrNight = hour >= DAY_START_HOUR && hour < DAY_END_HOUR ? "day" : "night";
        String temperatureStyle = styleOr(localWeather.temperature(), "medium");
        String precipeStyle = styleOr(localWeather.precipitation(), "sunny");
        String repoTarget = repoPath == null || repoPath.isEmpty()
            ? ""
            : "- Apply Styling To Repo: " + repoPath + "\n";

        return """

            %4$s- Render Background: %1$s
            - Render Tone: %2$s
            - Precipitation Use: Set per %3$s
            - Copy Paste Assets Server Assets:
               - Determine GUI Application Context:
                 - if game-like, then use assets, else do not use assets;
                 - if game-like:
                   - if "%3$s" is "cloudy" or "stormy", then use cloud.svg
                     - if "%2$s" is "cold", then use snow.svg, else use rain.svg
                   - else do not use cloud.svg, and style sky blue
                 - if "%1$s" is "day" use sun.svg, else use moon.svg
            """.formatted(dayOrNight, temperatureStyle, precipeStyle, repoTarget);
    }
}
```
<!--END_GUI-RENDER-WEATHER-->
### `gui/GuiDrawWeather.java`
<!--START_GUI-DRAW-WEATHER-->
```java
// Import dependencies
package org.example.weatherserver.gui;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Service;

// Import helpers
import org.example.weatherserver.utils.CategorizeLocalWeather.LocalWeather;

// The application wires this service into the tool callback provider, which
// keeps gui/ free of the MCP plumbing.
@Service
public class GuiDrawWeather {

    // Constant variables
    // The server runs from the project folder, where assets/ ships.
    private static final Path ASSETS_DIR = Paths.get("assets").toAbsolutePath();
    private static final String DAY_ASSET = "sun.svg";
    private static final String NIGHT_ASSET = "moon.svg";
    private static final String CLOUD_ASSET = "cloud.svg";
    private static final String RAIN_ASSET = "rain.svg";
    private static final String SNOW_ASSET = "snow.svg";
    private static final List<String> OVERCAST_STYLES = List.of("cloudy", "stormy");

    // Stand-in artwork for an asset the server does not ship, so the GUI always
    // has something to draw. Deliberately plain, since it only holds the place.
    private static final String MISSING_SVG =
        "<svg id=\"%1$s\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 360 360\">"
        + "<circle cx=\"180\" cy=\"180\" r=\"160\" fill=\"#d2d2d2\" stroke=\"#000\" stroke-width=\"8\"/>"
        + "<text x=\"180\" y=\"196\" fill=\"#000\" font-family=\"sans-serif\" font-size=\"44\""
        + " text-anchor=\"middle\">%2$s</text>"
        + "</svg>";

    /** Return the assets the current weather calls for, in draw order. */
    private static List<String> drawSet(LocalWeather localWeather, String dayOrNight) {
        String temperatureStyle = GuiRenderWeather.styleOr(localWeather.temperature(), "medium");
        String precipeStyle = GuiRenderWeather.styleOr(localWeather.precipitation(), "sunny");

        List<String> drawSet = new ArrayList<>();
        drawSet.add(dayOrNight.equals("day") ? DAY_ASSET : NIGHT_ASSET);
        if (OVERCAST_STYLES.contains(precipeStyle)) {
            drawSet.add(CLOUD_ASSET);
            drawSet.add(temperatureStyle.equals("cold") ? SNOW_ASSET : RAIN_ASSET);
        }
        return drawSet;
    }

    /** Draw the stand-in markup for an asset the server is missing. */
    private static String clicheSvg(String asset) {
        String name = asset.replaceFirst("[.][^.]+$", "");
        return MISSING_SVG.formatted(name, name.toUpperCase(Locale.ROOT));
    }

    @Tool(description = """
        Draw the SVG set for the current weather, as directives for the GUI app.

        Each asset the server ships is drawn from disk. Any asset it does not
        ship is drawn as a plain stand-in instead, so the draw set is never
        short. When the server ships no asset at all, the directives ask for the
        artwork to be generated rather than copied.
        """)
    public String drawWeatherSvg(
            @ToolParam(description = "Temperature style, one of hot, medium, cold") String temperature,
            @ToolParam(description = "Precipitation style, one of stormy, cloudy, sunny") String precipitation,
            @ToolParam(description = "Local time of day") String currentTime) {
        return draw(new LocalWeather(temperature, precipitation), currentTime);
    }

    /** Draw the SVG set for the current weather, as directives for the GUI app. */
    public String draw(LocalWeather localWeather, String currentTime) {
        int hour = GuiRenderWeather.hourOfDay(currentTime);
        String dayOrNight = hour >= GuiRenderWeather.DAY_START_HOUR
            && hour < GuiRenderWeather.DAY_END_HOUR ? "day" : "night";
        List<String> drawSet = drawSet(localWeather, dayOrNight);

        List<String> available = new ArrayList<>();
        List<String> missing = new ArrayList<>();
        for (String asset : drawSet) {
            Path path = ASSETS_DIR.resolve(asset);
            if (Files.isRegularFile(path)) {
                available.add("   - %s: %s".formatted(asset, path));
            }
            else {
                missing.add("   - %s:\n     %s".formatted(asset, clicheSvg(asset)));
            }
        }

        // Nothing on disk to draw from, so the artwork has to be generated.
        if (available.isEmpty()) {
            return """

                - Draw SVG Set: %s
                - Generate SVG:
                   - The server ships no asset for the current weather, so generate one SVG per
                     name in the draw set
                   - Match each one to the styling the GUI application already uses
                   - Keep every viewBox square and the markup self contained, with no external
                     references
                """.formatted(String.join(", ", drawSet));
        }

        List<String> serverPromptOutput = new ArrayList<>();
        serverPromptOutput.add("- Draw SVG Set: %s".formatted(String.join(", ", drawSet)));
        serverPromptOutput.add("- Draw From Server Assets:");
        serverPromptOutput.addAll(available);
        if (!missing.isEmpty()) {
            serverPromptOutput.add("- Draw Stand-In, Server Ships No Asset:");
            serverPromptOutput.addAll(missing);
        }
        serverPromptOutput.addAll(List.of(
            "- Add SVG Tool:",
            "   - For each language the GUI application is written in:",
            "     - Read the application and find the style pattern it already uses",
            "     - Add one lightweight SVG helper built on that style pattern:",
            "       - if the application groups behavior in classes, add a method",
            "       - else add a function",
            "     - The helper takes a name from the draw set and returns its markup",
            "   - Add no dependency, the helper stays lightweight"));

        return "\n" + String.join("\n", serverPromptOutput) + "\n";
    }
}
```
<!--END_GUI-DRAW-WEATHER-->

## Build Server

The project setup is deliberately different. Instead of one service file,
this server will have:

- Entry: `McpServerApplication.java`
- Weather tools: `WeatherService.java`
- Helper functions: `utils/`
  - `NwsClient.java`
  - `FormatAlert.java`
  - `CategorizeLocalWeather.java`
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
- GUI rendering: `gui/`
  - `GuiRenderWeather.java`
  - `GuiDrawWeather.java`
- GUI Graphics: `assets/`
  - `cloud.svg`
  - `sun.svg`
  - `moon.svg`
  - `rain.svg`
  - `snow.svg`

Build with `mvnw clean install`, which writes the runnable jar under `target/`.

## Add Server

**Claude Desktop**

<CodeGroup>

```json macOS/Linux
"weather-server-gui": {
  "command": "java",
  "args": [
    "-Dspring.ai.mcp.server.stdio=true",
    "-jar",
    "/PATH/TO/weather-server/target/weather-server-0.0.1-SNAPSHOT.jar"
  ]
}
```

```json Windows
    "weather-server-gui": {
      "command": "java",
      "args": [
        "-Dspring.ai.mcp.server.transport=STDIO",
        "-jar",
        "D:\\Users\\name\\path\\to\\weather-server\\target\\weather-server-0.0.1-SNAPSHOT.jar"
      ]
    }
```

</CodeGroup>

## Additionally

- [java-sdk](https://github.com/modelcontextprotocol/java-sdk)
- [MCP Server Boot Starter](https://docs.spring.io/spring-ai/reference/api/mcp/mcp-server-boot-starter-docs.html)
