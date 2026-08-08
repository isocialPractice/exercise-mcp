# Ruby Weather GUI Server

A variation of [weather-server-ruby](https://github.com/modelcontextprotocol/quickstart-resources/tree/main/weather-server-ruby) from the
[develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server#ruby),
focusing on GUI API usage.

> [!IMPORTANT]
> Don't write to stdout, or use `puts` or `print`.

## Use With Claude

Build the server first (see [Build Server](#build-server)), then register it.
The tools arrive as `get_alerts`, `get_forecast`, `render_weather`, and
`draw_weather_svg` under the `weather-server-gui` name.

**Claude Code (CLI or VS Code extension)**

Claude Code reads its own MCP config, not the Claude Desktop file. Bundler
needs the project folder as the working directory, so wrap the launch:

```batch
claude mcp add --scope user weather-server-gui -- cmd /c "cd /d D:\Users\name\path\to\weather-server && bundle exec ruby weather.rb"
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

<!-- - Tested on [street-crime](https://github.com/isocialPractice/street-crime/tree/local-weather) -->

## Quick Snippets

```
# output
logger = Logger.new($stderr) # no puts

# project setup
bundle add mcp

# build
server = MCP::Server.new(name: "<server>", version: "1.0.0", tools: [...])
```

<details>

<summary>Show Details</summary>

**Code**

```ruby
# Outputting
###############################################################################
# instead of puts use:
require "logger"
logger = Logger.new($stderr)
logger.info("Processing:") # writes to stderr

# Minimum Server
###############################################################################
require "mcp"

class Add < MCP::Tool
  tool_name "add"
  description "Add two numbers"
  input_schema(
    properties: {
      a: { type: "number" },
      b: { type: "number" }
    },
    required: ["a", "b"]
  )

  def self.call(a:, b:)
    MCP::Tool::Response.new([{ type: "text", text: (a + b).to_s }])
  end
end

server = MCP::Server.new(name: "Demo", version: "1.0.0", tools: [Add])
transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
```

**Commands**

```batch
:: Project Setup
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
md <server> & cd <server>
bundle init
bundle add mcp
new-item <server>.rb
```

</details>

## Setup Server Environment

> [!IMPORTANT]
> **Windows Users**: The `mcp` gem requires native compilation for some dependencies. Install [Ruby+Devkit](https://rubyinstaller.org/) with MSYS2, or if already installed, run `ridk install` and select option 3 (MSYS2 and MINGW development toolchain) to enable gem compilation.

1. Use `ruby` 2.7 or higher

```batch
ruby --version
```

2. Project setup

<CodeGroup>

```bash macOS/Linux
# Create a new directory for our project
mkdir weather
cd weather

# Create a Gemfile
bundle init

# Add the MCP SDK dependency
bundle add mcp

# Create our server file
touch weather.rb
```

```batch Windows
:: Create directory
mkdir weather-server
cd weather-server

:: Create a Gemfile
bundle init

:: Dependency installation
bundle add mcp

:: Server files
md utils gui
new-item weather.rb
```

</CodeGroup>

## Ruby MCP Server

The server created in this exercise is a variation of the below files.
<!--START_GEMFILE-->
```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gem "mcp"
```
<!--END_GEMFILE-->
### `weather.rb`
<!--START_SERVER-->
```ruby
# Import dependencies
require "mcp"

# Import helpers
require_relative "utils/make_nws_request"
require_relative "utils/format_alert"
require_relative "utils/categorize_local_weather"
require_relative "gui/gui_render_weather"
require_relative "gui/gui_draw_weather"

# Constant variables
NWS_API_BASE = "https://api.weather.gov"
LOCAL_TIME_FORMAT = "%H:%M:%S"

# Return the current local time, formatted for the GUI render tool.
def local_time
  Time.now.strftime(LOCAL_TIME_FORMAT)
end

# The gui input every gui tool shares: the categorized weather and the local
# time of day.
GUI_INPUT_SCHEMA = {
  properties: {
    temperature: {
      type: "string",
      description: "Temperature style, one of hot, medium, cold"
    },
    precipitation: {
      type: "string",
      description: "Precipitation style, one of stormy, cloudy, sunny"
    },
    current_time: {
      type: "string",
      description: "Local time of day"
    },
    repo_path: {
      type: "string",
      description: "Repository of the GUI application to style"
    }
  },
  required: ["temperature", "precipitation", "current_time"]
}.freeze

class GetAlerts < MCP::Tool
  extend MakeNwsRequest
  extend FormatAlert

  tool_name "get_alerts"
  description "Get weather alerts for a US state"
  input_schema(
    properties: {
      state: {
        type: "string",
        description: "Two-letter US state code (e.g. CA, NY)"
      }
    },
    required: ["state"]
  )

  def self.call(state:)
    url = "#{NWS_API_BASE}/alerts/active/area/#{state.upcase}"
    data = make_nws_request(url)

    if data.nil? || !data.key?("features")
      return MCP::Tool::Response.new([{
        type: "text",
        text: "Unable to fetch alert or alert not found."
      }])
    end

    if data["features"].empty?
      return MCP::Tool::Response.new([{
        type: "text",
        text: "No active alert for the state."
      }])
    end

    alerts = data["features"].map { |feature| format_alert(feature) }
    MCP::Tool::Response.new([{
      type: "text",
      text: alerts.join("\n---\n")
    }])
  end
end

class GetForecast < MCP::Tool
  extend MakeNwsRequest
  extend CategorizeLocalWeather
  extend GuiRenderWeather

  tool_name "get_forecast"
  description "Get weather forecast for a location"
  input_schema(
    properties: {
      latitude: {
        type: "number",
        description: "Latitude of the location"
      },
      longitude: {
        type: "number",
        description: "Longitude of the location"
      }
    },
    required: ["latitude", "longitude"]
  )

  def self.call(latitude:, longitude:)
    # forecast grid endpoint
    points_url = "#{NWS_API_BASE}/points/#{latitude},#{longitude}"
    points_data = make_nws_request(points_url)

    if points_data.nil?
      return MCP::Tool::Response.new([{
        type: "text",
        text: "Unable to fetch forecast data for this location."
      }])
    end

    # Get the forecast URL from points response
    forecast_url = points_data.dig("properties", "forecast")
    forecast_data = forecast_url && make_nws_request(forecast_url)

    if forecast_data.nil?
      return MCP::Tool::Response.new([{
        type: "text",
        text: "Unable to fetch detailed forecast for this location."
      }])
    end

    periods = forecast_data.dig("properties", "periods") || []

    if periods.empty?
      return MCP::Tool::Response.new([{
        type: "text",
        text: "No forecast periods available for this location."
      }])
    end

    forecasts = periods.first(5).map do |period| # next 5 periods
      <<~FORECAST

        #{period["name"]}:
        Temperature: #{period["temperature"]}°#{period["temperatureUnit"]}
        Wind: #{period["windSpeed"]} #{period["windDirection"]}
        Forecast: #{period["detailedForecast"]}
      FORECAST
    end

    current_forecast = forecasts.join("\n---\n")
    # The first period is the current one, so the GUI styles from it.
    render_data = categorize_local_weather(periods.first)
    render_directives = render_weather(render_data, local_time)

    MCP::Tool::Response.new([{
      type: "text",
      text: <<~RESULT
        #{current_forecast}
        ---
        Local Weather: #{format_local_weather(render_data)}
        #{render_directives}
      RESULT
    }])
  end
end

# render_weather and draw_weather_svg are defined in gui/ so those modules stay
# free of the server instance, so expose them as tools from here.
class RenderWeather < MCP::Tool
  extend GuiRenderWeather

  tool_name "render_weather"
  description GuiRenderWeather::RENDER_WEATHER_DESCRIPTION
  input_schema(**GUI_INPUT_SCHEMA)

  def self.call(temperature:, precipitation:, current_time:, repo_path: nil)
    local_weather = { "Temperature" => temperature, "Precipitation" => precipitation }
    MCP::Tool::Response.new([{
      type: "text",
      text: render_weather(local_weather, current_time, repo_path)
    }])
  end
end

class DrawWeatherSvg < MCP::Tool
  extend GuiDrawWeather

  tool_name "draw_weather_svg"
  description GuiDrawWeather::DRAW_WEATHER_SVG_DESCRIPTION
  input_schema(**GUI_INPUT_SCHEMA)

  # repo_path arrives through the shared schema; only the render tool reads it.
  def self.call(temperature:, precipitation:, current_time:, repo_path: nil)
    local_weather = { "Temperature" => temperature, "Precipitation" => precipitation }
    MCP::Tool::Response.new([{
      type: "text",
      text: draw_weather_svg(local_weather, current_time)
    }])
  end
end

server = MCP::Server.new(
  name: "weather-server",
  version: "0.1.0",
  tools: [GetAlerts, GetForecast, RenderWeather, DrawWeatherSvg]
)

transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
```
<!--END_SERVER-->
### `utils/make_nws_request.rb`
<!--START_UTILS-MAKE-NWS-REQUEST-->
```ruby
# Import dependencies
require "json"
require "net/http"
require "uri"

module MakeNwsRequest
  # Constant variables
  USER_AGENT = "weather-app/1.0"

  # Make a request to the NWS API with proper error handling.
  def make_nws_request(url)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    request["Accept"] = "application/geo+json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError
    nil
  end
end
```
<!--END_UTILS-MAKE-NWS-REQUEST-->
### `utils/format_alert.rb`
<!--START_UTILS-FORMAT-ALERT-->
```ruby
module FormatAlert
  # Format an alert feature into a readable string.
  def format_alert(feature)
    properties = feature["properties"]

    <<~ALERT

      Event: #{properties["event"] || "Unknown"}
      Area: #{properties["areaDesc"] || "Unknown"}
      Severity: #{properties["severity"] || "Unknown"}
      Description: #{properties["description"] || "No description available"}
      Instruction: #{properties["instruction"] || "No specific instructions provided"}
    ALERT
  end
end
```
<!--END_UTILS-FORMAT-ALERT-->
### `utils/categorize_local_weather.rb`
<!--START_CATEGORIZE-LOCAL-WEATHER-->
```ruby
module CategorizeLocalWeather
  # Constant variables
  HOT_THRESHOLD_F = 80.0
  COLD_THRESHOLD_F = 32.0
  STORM_TERMS = ["thunder", "storm", "squall", "hail", "blizzard", "torrential"].freeze
  RAIN_TERMS = ["rain", "shower", "drizzle", "snow", "sleet", "freezing", "precipitation"].freeze
  CLOUD_TERMS = ["cloud", "overcast", "fog", "haze", "mist"].freeze
  SEVERE_LEVELS = ["high", "severe", "extreme"].freeze

  # NWS forecast periods and alert properties describe the same conditions
  # under different key names, so each lookup below accepts either shape.
  TEMPERATURE_KEYS = ["temperature", "temp"].freeze
  UNIT_KEYS = ["temperatureUnit", "unit"].freeze
  CONDITION_KEYS = ["detailedForecast", "shortForecast", "forecast", "event", "description"].freeze
  SEVERITY_KEYS = ["severity"].freeze

  # Return the first populated value among keys, matched without case.
  def lookup(forecast, keys, default = "")
    normalized = forecast.transform_keys { |key| key.to_s.downcase }
    keys.each do |key|
      value = normalized[key.downcase]
      return value unless value.nil? || value == ""
    end
    default
  end

  # Join every populated value among keys into one searchable string.
  def collect(forecast, keys)
    normalized = forecast.transform_keys { |key| key.to_s.downcase }
    found = keys.filter_map do |key|
      value = normalized[key.downcase]
      value.to_s unless value.nil? || value == ""
    end
    found.join(" ")
  end

  # Convert a reported temperature to Fahrenheit, or nil when unusable.
  def to_fahrenheit(temperature, unit)
    degrees = Float(temperature)

    return degrees * 9.0 / 5.0 + 32.0 if unit.strip.upcase.start_with?("C")

    degrees
  rescue ArgumentError, TypeError
    nil
  end

  # Bucket the reported temperature into hot, cold, or medium.
  def categorize_temperature(forecast)
    degrees = to_fahrenheit(
      lookup(forecast, TEMPERATURE_KEYS, nil),
      lookup(forecast, UNIT_KEYS, "F").to_s
    )

    return "medium" if degrees.nil?
    return "hot" if degrees >= HOT_THRESHOLD_F
    return "cold" if degrees < COLD_THRESHOLD_F

    "medium"
  end

  # Bucket the reported conditions into stormy, cloudy, or sunny.
  def categorize_precipitation(forecast)
    conditions = collect(forecast, CONDITION_KEYS).downcase
    severity = lookup(forecast, SEVERITY_KEYS).to_s.downcase
    is_severe = SEVERE_LEVELS.include?(severity)

    return "stormy" if STORM_TERMS.any? { |term| conditions.include?(term) }

    if RAIN_TERMS.any? { |term| conditions.include?(term) }
      return is_severe ? "stormy" : "cloudy"
    end

    return "cloudy" if CLOUD_TERMS.any? { |term| conditions.include?(term) }

    "sunny"
  end

  # Reduce a forecast period to the two styling values the GUI renders from:
  # "Temperature" as one of hot, medium, cold, and "Precipitation" as one of
  # stormy, cloudy, sunny.
  def categorize_local_weather(forecast)
    {
      "Temperature" => categorize_temperature(forecast),
      "Precipitation" => categorize_precipitation(forecast)
    }
  end

  # Format categorized weather as a single readable line.
  def format_local_weather(local_weather)
    temperature = local_weather["Temperature"] || "medium"
    precipitation = local_weather["Precipitation"] || "sunny"
    "Temperature: #{temperature}, Precipitation: #{precipitation}"
  end
end
```
<!--END_CATEGORIZE-LOCAL-WEATHER-->
### `gui/gui_render_weather.rb`
<!--START_GUI-RENDER-WEATHER-->
```ruby
# Import dependencies
require "time"

# The server owns the MCP::Server instance and registers this module through a
# tool class, which keeps gui/ requireable from weather.rb without a circular
# reference.
module GuiRenderWeather
  # Constant variables
  DAY_START_HOUR = 8  # 8AM
  DAY_END_HOUR = 20   # 8PM
  TIME_FORMATS = ["%H:%M:%S", "%H:%M", "%I:%M:%S %p", "%I:%M %p"].freeze

  RENDER_WEATHER_DESCRIPTION = <<~DESCRIPTION
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

       The repo_path argument, when provided, names the repository of the GUI
       application parts A and B apply to.
  DESCRIPTION

  # Return the hour of day for a time given as text, or now when unparseable.
  def hour_of_day(current_time)
    text = current_time.to_s.strip
    TIME_FORMATS.each do |time_format|
      return Time.strptime(text, time_format).hour
    rescue ArgumentError
      next
    end

    # Unparseable input still has to render something, so fall back to now.
    Time.now.hour
  end

  # Render current GUI application based on local weather.
  #
  # local_weather: temperature, precipitation
  # current_time: local time of day
  def render_weather(local_weather, current_time, repo_path = nil)
    hour = hour_of_day(current_time)
    day_or_night = hour >= DAY_START_HOUR && hour < DAY_END_HOUR ? "day" : "night"
    temperature_style = local_weather["Temperature"] || "medium"
    precipe_style = local_weather["Precipitation"] || "sunny"
    repo_target = repo_path.nil? || repo_path.empty? ? "" : "- Apply Styling To Repo: #{repo_path}\n"

    <<~OUTPUT

      #{repo_target}- Render Background: #{day_or_night}
      - Render Tone: #{temperature_style}
      - Precipitation Use: Set per #{precipe_style}
      - Copy Paste Assets Server Assets:
         - Determine GUI Application Context:
           - if game-like, then use assets, else do not use assets;
           - if game-like:
             - if "#{precipe_style}" is "cloudy" or "stormy", then use cloud.svg
               - if "#{temperature_style}" is "cold", then use snow.svg, else use rain.svg
             - else do not use cloud.svg, and style sky blue
           - if "#{day_or_night}" is "day" use sun.svg, else use moon.svg
    OUTPUT
  end
end
```
<!--END_GUI-RENDER-WEATHER-->
### `gui/gui_draw_weather.rb`
<!--START_GUI-DRAW-WEATHER-->
```ruby
# Day and night already have one definition in the render module, and both
# modules ship in gui/, so reuse it rather than read the clock twice.
require_relative "gui_render_weather"

# The server owns the MCP::Server instance and registers this module through a
# tool class, which keeps gui/ requireable from weather.rb without a circular
# reference.
module GuiDrawWeather
  include GuiRenderWeather

  # Constant variables
  ASSETS_DIR = File.expand_path("../assets", __dir__)
  DAY_ASSET = "sun.svg"
  NIGHT_ASSET = "moon.svg"
  CLOUD_ASSET = "cloud.svg"
  RAIN_ASSET = "rain.svg"
  SNOW_ASSET = "snow.svg"
  OVERCAST_STYLES = ["cloudy", "stormy"].freeze

  # Stand-in artwork for an asset the server does not ship, so the GUI always
  # has something to draw. Deliberately plain, since it only holds the place.
  MISSING_SVG =
    '<svg id="%<name>s" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 360">' \
    '<circle cx="180" cy="180" r="160" fill="#d2d2d2" stroke="#000" stroke-width="8"/>' \
    '<text x="180" y="196" fill="#000" font-family="sans-serif" font-size="44"' \
    ' text-anchor="middle">%<label>s</text>' \
    "</svg>"

  DRAW_WEATHER_SVG_DESCRIPTION = <<~DESCRIPTION
    Draw the SVG set for the current weather, as directives for the GUI app.

    Each asset the server ships is drawn from disk. Any asset it does not
    ship is drawn as a plain stand-in instead, so the draw set is never
    short. When the server ships no asset at all, the directives ask for the
    artwork to be generated rather than copied.
  DESCRIPTION

  # Return the assets the current weather calls for, in draw order.
  def draw_set(local_weather, day_or_night)
    temperature_style = local_weather["Temperature"] || "medium"
    precipe_style = local_weather["Precipitation"] || "sunny"

    assets = [day_or_night == "day" ? DAY_ASSET : NIGHT_ASSET]
    if OVERCAST_STYLES.include?(precipe_style)
      assets << CLOUD_ASSET
      assets << (temperature_style == "cold" ? SNOW_ASSET : RAIN_ASSET)
    end
    assets
  end

  # Draw the stand-in markup for an asset the server is missing.
  def cliche_svg(asset)
    name = File.basename(asset, ".*")
    format(MISSING_SVG, name: name, label: name.upcase)
  end

  # Draw the SVG set for the current weather, as directives for the GUI app.
  #
  # local_weather: temperature, precipitation
  # current_time: local time of day
  def draw_weather_svg(local_weather, current_time)
    hour = hour_of_day(current_time)
    day_or_night = hour >= DAY_START_HOUR && hour < DAY_END_HOUR ? "day" : "night"
    assets = draw_set(local_weather, day_or_night)

    available = []
    missing = []
    assets.each do |asset|
      path = File.join(ASSETS_DIR, asset)
      if File.file?(path)
        available << "   - #{asset}: #{path}"
      else
        missing << "   - #{asset}:\n     #{cliche_svg(asset)}"
      end
    end

    # Nothing on disk to draw from, so the artwork has to be generated.
    if available.empty?
      return <<~OUTPUT

        - Draw SVG Set: #{assets.join(", ")}
        - Generate SVG:
           - The server ships no asset for the current weather, so generate one SVG per
             name in the draw set
           - Match each one to the styling the GUI application already uses
           - Keep every viewBox square and the markup self contained, with no external
             references
      OUTPUT
    end

    server_prompt_output = ["- Draw SVG Set: #{assets.join(", ")}"]
    server_prompt_output << "- Draw From Server Assets:"
    server_prompt_output.concat(available)
    unless missing.empty?
      server_prompt_output << "- Draw Stand-In, Server Ships No Asset:"
      server_prompt_output.concat(missing)
    end
    server_prompt_output.concat([
      "- Add SVG Tool:",
      "   - For each language the GUI application is written in:",
      "     - Read the application and find the style pattern it already uses",
      "     - Add one lightweight SVG helper built on that style pattern:",
      "       - if the application groups behavior in classes, add a method",
      "       - else add a function",
      "     - The helper takes a name from the draw set and returns its markup",
      "   - Add no dependency, the helper stays lightweight"
    ])

    "\n#{server_prompt_output.join("\n")}\n"
  end
end
```
<!--END_GUI-DRAW-WEATHER-->

## Build Server

The project setup is deliberately different. Instead of one `weather.rb` file,
this server will have:

- Entry: `weather.rb`
- Helper functions: `utils/`
  - `make_nws_request.rb`
  - `format_alert.rb`
  - `categorize_local_weather.rb`
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
  - `gui_render_weather.rb`
  - `gui_draw_weather.rb`
- GUI Graphics: `assets/`
  - `cloud.svg`
  - `sun.svg`
  - `moon.svg`
  - `rain.svg`
  - `snow.svg`

Run with `bundle exec ruby weather.rb` from the project folder.

## Add Server

**Claude Desktop**

<CodeGroup>

```json macOS/Linux
"weather-server-gui": {
  "command": "bundle",
  "args": ["exec", "ruby", "weather.rb"],
  "cwd": "/PATH/TO/weather-server"
}
```

```json Windows
    "weather-server-gui": {
      "command": "bundle",
      "args": ["exec", "ruby", "weather.rb"],
      "cwd": "D:\\Users\\name\\path\\to\\weather-server"
    }
```

</CodeGroup>

## Additionally

- [ruby-sdk](https://github.com/modelcontextprotocol/ruby-sdk)
