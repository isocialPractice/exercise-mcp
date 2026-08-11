# Constants for each Server

## Build Server

The project setup is deliberately different. Instead of one `<server>.lang-extension` file,
this server will have:

> [!NOTE]
> File names are listed in `snake_case`. Name each one the way the target
> language conventionally names files - `make_nws_request.py` in Python,
> `makeNwsRequest.ts` in TypeScript.

- Entry: `server.lang-extension`
- Helper functions: `utils/`
  - `make_nws_request.lang-extension`
  - `format_alert.lang-extension`
  - `categorize_local_weather.lang-extension`
    - Summary: for GUI instance of server, so weather will change display according to:
      - Temperature: Hot, Mediumm, or Cold
        - Cold: **temp. < 32°F(0°C)**
        - Medium: **temp. > `cold` && temp. < 80°F(26.67°C)**
        - Hot: **temp. >= 80°F(26.67°C)**
        - Each determins effect for `["stormy", "cloudy", "sunny"]`
      - Precipitation: Stormy, Cloudy, or Sunny
        - If stormy or cloudy, then:
          - If stromy, then more precipitation; else less precipitation
          - If cold, then snow; else rain
          - If medium or hot, then:
            - Medium: more gray toned
            - Hot: more dark toned
      - Time of day:
        - If local time is past 8PM and less than 8AM, then it is daytime; else it is night time
          - Render the GUI application accordingly
- GUI Rendering and SVG Tool: `gui/`
  - `render_weather.lang-extension`
  - `draw_weather.lang-extension`
    - Summary: returns the draw set for the current weather as directives, so
      the GUI application draws the same conditions it is styled for:
      - Every asset the server ships is drawn from `assets/`
      - Any asset in the draw set that the server does not ship is drawn as a
        plain cliche stand-in instead, so the set is never short
      - When the server ships no asset at all, the directives ask for the
        artwork to be generated rather than copied
      - Add one lightweight SVG helper per language the GUI application is
        written in, built on the style pattern that application already uses:
        a method where behavior is grouped in classes, a function otherwise
      - The helper takes a name from the draw set and returns its markup, and
        adds no dependency
- GUI Graphics: `assets/`
  - `cloud.svg`
  - `moon.svg`
  - `rain.svg`
  - `snow.svg`
  - `sun.svg`
