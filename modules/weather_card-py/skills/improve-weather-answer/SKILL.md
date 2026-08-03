---
name: improve-weather-answer
description: Extend the weather-card answer when a request goes beyond the card - the exact National Weather Service API calls to make and the HTML fragment shape render_weather accepts as extra_html. Use when a weather ask (hourly detail, active alerts, comparisons) exceeds what the card shows by default.
---

# Improve a Weather Answer

The `weather_card-py` server is the whole weather answer. When a request goes
beyond what its card shows, do not call another weather tool - extend this one.
Two levers, in order of preference:

1. **`days` parameter** - forecasts up to 8 days are built in and ON BY
   DEFAULT (`days=8`): a plain `render_weather(location="Springfield, IL")`
   already includes the outlook strip. Pass `days=1` for current conditions
   only. No extra work needed for any forecast ask.
2. **`extra_html` parameter** - for anything else, fetch the data yourself
   (calls below), build a small HTML fragment (shape below), and pass it:
   `render_weather(location="Springfield, IL", extra_html="<div>...</div>")`.
   The card renders it below the weather panel.

## The API calls

All keyless. US locations only.

| Need | Call |
| --- | --- |
| Name -> coordinates | `GET https://geocoding-api.open-meteo.com/v1/search?name=Springfield,%20IL&count=5&language=en&format=json` - use `results[]` where `country_code == "US"`; read `latitude`, `longitude`, `name`, `admin1` |
| Point -> forecast URLs | `GET https://api.weather.gov/points/{lat},{lon}` - read `properties.forecast`, `properties.forecastHourly`; follow the 301 redirect (high-precision coords redirect to 4-decimal) |
| Daily forecast | `GET {properties.forecast}` - `properties.periods[]`: `name`, `temperature`, `shortForecast`, `isDaytime`, `startTime`, `probabilityOfPrecipitation.value` (nullable - default 0) |
| Hourly forecast | `GET {properties.forecastHourly}` - same period fields, one per hour |
| Active alerts | `GET https://api.weather.gov/alerts/active?point={lat},{lon}` - `features[].properties`: `event`, `severity`, `headline` |

Send a descriptive `User-Agent` when calling from a script; browser calls
already carry one.

## The HTML fragment

Rules the card enforces or relies on:

- **Presentational only.** The fragment is set via `innerHTML`, so `<script>`
  tags never execute. Markup and inline styles work; JavaScript does not.
- **Match the card's theme** by using its CSS variables instead of hard-coded
  colors: `var(--fg)` text, `var(--muted)` secondary text, `var(--surface)`
  background, `var(--accent)` / `var(--accent-soft)` highlight, `var(--radius)`
  corners. These are already set to the host's light/dark theme.
- **Keep it small** - one screenful, no external images or fonts.

Example - an hourly strip built from `forecastHourly`:

```html
<div style="background: var(--surface); border-radius: var(--radius);
            padding: 12px 16px; display: flex; gap: 4px; text-align: center;">
  <div style="flex: 1;">
    <div style="font-size: 11px; color: var(--muted);">2 PM</div>
    <div style="font-weight: 600;">91&deg;</div>
    <div style="font-size: 11px; color: var(--accent); font-weight: 600;">35%</div>
  </div>
  <!-- one block per hour, 6-8 hours max -->
</div>
```

## What not to do

- Do not call `weather_fetch` or any other weather tool - two sources means
  two conflicting cards.
- Do not spawn a subprocess, another model, or a background job - you are
  already the model in the loop; fetch and format directly.
- Do not put raw API JSON in `extra_html` - summarize into markup.
