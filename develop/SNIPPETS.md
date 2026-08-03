# Constants for each Server

## Build Server

The project setup is deliberately different. Instead of one `<server>.lang-extension` file,
this server will have:

- Entry: `server.lang-extension`
- Helper functions: `utils/`
  - `(commonLangSyntax.use("_" | camel-case)=>`: `make_nws_request.lang-extension`
  - `(commonLangSyntax.use("_" | camel-case)=>`: `dormat_alert.lang-extension`
  - `(commonLangSyntax.use("_" | camel-case)=>`: `categorize_local_weather.lang-extension`
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
  - `(commonLangSyntax.use("_" | camel-case)=>`: `render_weather.lang-extension`
  - `(commonLangSyntax.use("_" | camel-case, drawsSvg())=>`: `draw_weather.lang-extension`
<!--
```
(draw_weather.lang-extension)=> shorthand drawsSvg() {
  adds.svgTool(drawWeatherSVG, use.currentWeather(()=> {if asset.svg not in currentWeather, then draw cliche(weather.missingSVG);}))=> {
    for.each(language.server()-> add lightweight.svgTool(styles: app): [method, function] { get(guiApp).find(style.pattern); make.svgTool(base.onStylePattern())})
  }
}
```
-->
- GUI Graphics: `assets/`
  - `cloud.svg`
  - `moon.svg`
  - `rain.svg`
  - `snow.svg`
  - `sun.svg`
