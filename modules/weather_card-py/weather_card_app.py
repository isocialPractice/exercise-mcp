"""
weather_card_app.py
===========================================================================
A standalone MCP Apps (SEP-1865) server: an interactive local-weather card
for Claude Desktop.

New feature, self-contained. Nothing here edits your existing weather-server
files; drop this in as its own server and register it with Claude Desktop.

WHAT IT DOES
    - Exposes one tool, `render_weather`, that fetches conditions from the
      National Weather Service on demand (one request per call) and returns an
      interactive card: current conditions over a day-by-day outlook strip.
      The 8-day forecast is the DEFAULT (`days=8`); `days=1` collapses the
      card to current conditions only. NWS publishes about a week ahead, so
      the strip holds 7-8 entries depending on the time of day.
    - The card is a `ui://` resource the host renders in a sandboxed iframe. It
      reads the host's theme via `ui/initialize` and matches it; the weather
      condition drives only the card's accent color.
    - `extra_html` is the model's improve channel: for asks the card does not
      cover (hourly detail, alerts), the model fetches NWS data itself and
      passes a small presentational fragment the card renders below the panel.
      Scripts never execute there. The exact API calls and markup shapes live
      in skills/improve-weather-answer/ next to this file -- no subprocess, no
      second model, no other weather tool.

INDEPENDENT BY DEFAULT
    This server needs no other MCP server, no other tool, and no API key.
    Location comes from inside; weather comes straight from NWS. In order,
    first hit wins:
      1. Explicit `latitude` + `longitude`   - exact point, no lookup.
      2. `location` ("Springfield, IL")      - geocoded here, by name.
      3. WEATHER_CARD_DEFAULT_LOCATION       - your configured home location.
      4. The host's public IP                - approximate, city-level at best.
    Step 4 is the only one that tells a third party anything about you, and it
    only runs when the first three are empty. US locations only (NWS is).
    The card is independent too: the resource declares CSP connect domains, so
    if the host ever fails to deliver the tool result, the card fetches the
    same NWS data itself from inside the iframe -- once, on render, no timer.

DIRECTION OF CONTROL (why this is the legitimate shape)
    Host (Claude Desktop) ── renders ui:// resource in sandboxed iframe ─▶ card
    Host ── sends hostContext (theme, size) ───────────────────────────▶ card
    Host ── sends tool result (structuredContent) ─────────────────────▶ card
    card ── ui/initialize: "ready, send context" ─────────────────────▶ Host
    The card styles pixels inside its own box. It never repaints Claude
    Desktop, never touches the app frame, and starts no background loop in the
    host. Live data comes from an explicit tool call, not a hidden timer.

REQUIREMENTS
    pip install mcp httpx      # mcp 2.x

THE THREE THINGS THAT MAKE THE CARD ACTUALLY RENDER
    Each of these fails silently on its own, which is why a card can be
    mounted, empty, and invisible all at the same time:
      1. `_meta.ui.resourceUri` on the tool. Registering through the `Apps`
         extension stamps it. `io.modelcontextprotocol/ui` is the extension's
         negotiation identifier, NOT a `_meta` key -- used as one it is ignored.
      2. `structuredContent` on the result. The card paints from it, so the
         tool needs `structured_output=True` and a `dict[str, Any]` return.
         A bare `-> dict` gives the SDK no output schema, so the payload ships
         as text only and the card has nothing to draw.
      3. The three-step handshake, below in the view. The host withholds the
         tool result until the view sends `ui/notifications/initialized`.

REGISTER WITH CLAUDE DESKTOP
    Edit claude_desktop_config.json (Settings ▸ Developer ▸ Edit Config) and add:

    {
      "mcpServers": {
        "weather-card": {
          "command": "python",
          "args": ["/absolute/path/to/weather_card_app.py"]
        }
      }
    }

    Restart Claude Desktop. Then ask it for the weather at a location and it
    will call render_weather; on a host with MCP Apps support the card renders
    inline, and everywhere else the plain-text summary shows instead.
===========================================================================
"""

from __future__ import annotations

import os
from datetime import datetime
from typing import Any

import httpx
from mcp.server.apps import Apps, ResourceCsp
from mcp.server.mcpserver import MCPServer

NWS_API_BASE = "https://api.weather.gov"
# Place name -> coordinates. Keyless, and the only geocoder used here.
GEOCODE_API = "https://geocoding-api.open-meteo.com/v1/search"
# Last-resort "where am I" when no location is given and none is configured.
IP_LOCATION_API = "https://ipapi.co/json/"
# Set this in claude_desktop_config.json's env block to skip the IP lookup.
DEFAULT_LOCATION_ENV = "WEATHER_CARD_DEFAULT_LOCATION"
# NWS asks every client to send a descriptive User-Agent with contact info.
USER_AGENT = "weather-card-app/0.1 (you@example.com)"

UI_RESOURCE_URI = "ui://weather/card"

# The Apps extension owns the tool -> ui:// linkage and the app MIME type.
# The server itself is built at the bottom of the file, after every
# registration exists, because MCPServer copies an extension's tools and
# resources at construction time.
apps = Apps()


# --------------------------------------------------------------------------- #
# Live data (on demand)                                                         #
# --------------------------------------------------------------------------- #
def _pop(period: dict) -> int:
    """Probability of precipitation for a period, defaulting to 0."""
    value = (period.get("probabilityOfPrecipitation") or {}).get("value")
    return value if value is not None else 0


def _classify(short_forecast: str) -> str:
    """Map NWS free-text ('Partly Cloudy', 'Rain Likely') to a card condition."""
    s = short_forecast.lower()
    if any(k in s for k in ("thunder", "storm")):
        return "storm"
    if any(k in s for k in ("snow", "sleet", "flurr", "ice", "wintry")):
        return "snow"
    if any(k in s for k in ("rain", "shower", "drizzle")):
        return "rain"
    if any(k in s for k in ("cloud", "overcast", "fog", "haze")):
        return "clouds"
    return "clear"


def _split_place(query: str) -> tuple[str, str]:
    """Split free text into (city, region), repairing a missing comma.

    The geocoder wants "Springfield, IL" and returns nothing at all for
    "Springfield IL", so a bare trailing state code is promoted to a region.
    """
    text = " ".join(query.split())
    if "," in text:
        city, _, region = text.partition(",")
        return city.strip(), region.strip()
    head, _, tail = text.rpartition(" ")
    if head and len(tail) == 2 and tail.isalpha():
        return head.strip(), tail.strip()
    return text, ""


async def _geocode(client: httpx.AsyncClient, query: str) -> dict[str, Any]:
    """Resolve a place name to US coordinates. No other server involved."""
    city, region = _split_place(query)
    resp = await client.get(
        GEOCODE_API,
        params={
            "name": f"{city}, {region}" if region else city,
            "count": 10,
            "language": "en",
            "format": "json",
        },
    )
    resp.raise_for_status()
    matches = resp.json().get("results") or []

    # NWS is US-only, so anything else is a dead end no matter how well it matched.
    usable = [m for m in matches if m.get("country_code") == "US"]
    if not usable:
        if matches:
            raise ValueError(
                f"{query!r} resolves to {matches[0].get('country_code')}, and the "
                "National Weather Service only covers US locations."
            )
        raise ValueError(
            f"No US location found for {query!r}. Try a 'City, ST' form such as "
            "'Springfield, IL'."
        )

    # Prefer the city itself over near-misses like 'Springfield Park'.
    exact = [m for m in usable if (m.get("name") or "").casefold() == city.casefold()]
    hit = (exact or usable)[0]
    label = ", ".join(p for p in (hit.get("name"), hit.get("admin1")) if p)
    return {"latitude": hit["latitude"], "longitude": hit["longitude"], "label": label}


async def _locate_by_ip(client: httpx.AsyncClient) -> dict[str, Any]:
    """Approximate the caller's location from the host's public IP.

    City-level at best and often off by a county, so it is the last resort --
    set DEFAULT_LOCATION_ENV to skip it entirely.
    """
    resp = await client.get(IP_LOCATION_API)
    resp.raise_for_status()
    data = resp.json()
    if data.get("latitude") is None or data.get("longitude") is None:
        raise ValueError(
            "Could not determine a location from this network. Pass a location "
            f"such as 'Springfield, IL', or set {DEFAULT_LOCATION_ENV}."
        )
    label = ", ".join(p for p in (data.get("city"), data.get("region")) if p)
    return {
        "latitude": float(data["latitude"]),
        "longitude": float(data["longitude"]),
        "label": label,
    }


async def _resolve_location(
    client: httpx.AsyncClient,
    location: str | None,
    latitude: float | None,
    longitude: float | None,
) -> dict[str, Any]:
    """Turn whatever the caller supplied into coordinates, self-contained.

    Explicit coordinates win, then a named location, then the configured
    default, then the public-IP estimate.
    """
    if (latitude is None) != (longitude is None):
        raise ValueError(
            "latitude and longitude must be given together; pass a location "
            "name instead to have it looked up."
        )
    if latitude is not None and longitude is not None:
        return {"latitude": latitude, "longitude": longitude, "label": ""}
    if location and location.strip():
        return await _geocode(client, location)
    configured = os.environ.get(DEFAULT_LOCATION_ENV, "").strip()
    if configured:
        return await _geocode(client, configured)
    return await _locate_by_ip(client)


async def _fetch_current(
    client: httpx.AsyncClient, latitude: float, longitude: float
) -> dict[str, Any]:
    """One /points lookup + one /forecast fetch. Returns the current period."""
    headers = {"Accept": "application/geo+json"}
    pts = await client.get(
        f"{NWS_API_BASE}/points/{latitude},{longitude}", headers=headers
    )
    if pts.status_code == 404:
        raise ValueError(
            f"The National Weather Service has no forecast grid for "
            f"{latitude},{longitude}. It covers US locations only."
        )
    pts.raise_for_status()
    points = pts.json()["properties"]

    fc = await client.get(points["forecast"], headers=headers)
    fc.raise_for_status()
    periods = fc.json()["properties"]["periods"]
    period = periods[0]

    loc = (points.get("relativeLocation") or {}).get("properties") or {}
    city = ", ".join(p for p in (loc.get("city"), loc.get("state")) if p)

    # Day-by-day outlook: one entry per daytime period, up to 8. The tool
    # slices this to the number of days the caller actually asked for.
    days: list[dict[str, Any]] = []
    for p in periods:
        if not p.get("isDaytime"):
            continue
        try:
            label = datetime.fromisoformat(p["startTime"]).strftime("%a")
        except (KeyError, ValueError):
            label = (p.get("name") or "")[:3]
        days.append(
            {
                "day": label,
                "high": p["temperature"],
                "precipitationChance": _pop(p),
                "condition": _classify(p.get("shortForecast", "")),
            }
        )
        if len(days) >= 8:
            break

    return {
        "city": city,
        "temperatureF": period["temperature"],  # US points report °F
        "precipitationChance": _pop(period),
        "condition": _classify(period.get("shortForecast", "")),
        "shortForecast": period.get("shortForecast", ""),
        "periodName": period.get("name", ""),
        "days": days,
    }


# --------------------------------------------------------------------------- #
# 1. The tool, bound to the UI resource. `apps.tool` stamps the tool -> ui://    #
#    link the host reads; the card itself is registered at the bottom, once      #
#    CARD_HTML exists. The tool ALWAYS returns a text summary as well, so        #
#    non-Apps hosts and the model still get a usable result.                     #
# --------------------------------------------------------------------------- #
@apps.tool(resource_uri=UI_RESOURCE_URI, structured_output=True)
async def render_weather(
    location: str | None = None,
    latitude: float | None = None,
    longitude: float | None = None,
    days: int = 8,
    extra_html: str | None = None,
) -> dict[str, Any]:
    """Show local weather as an interactive card: current conditions plus a
    day-by-day outlook strip, up to 8 days (the default).

    Pass `location` as "City, ST" (for example "Springfield, IL"). Omit every
    argument to use the caller's own location. Latitude/longitude are an
    escape hatch for a precise point and must be given together.

    `days` (1-8, default 8) controls the outlook strip: the 8-day forecast is
    on by default, so "render the 8 day forecast" needs no extra arguments --
    and it is never a job for another tool. `days=1` collapses the card to
    current conditions only. NWS publishes about a week ahead, so the strip
    holds 7-8 entries depending on the time of day.

    For weather asks this card does not cover (hourly detail, active alerts,
    a comparison), still do not call another weather tool: fetch what you need
    from api.weather.gov yourself and pass a small presentational HTML
    fragment as `extra_html`; the card renders it below the weather panel
    (scripts never execute there). The exact API calls and markup shapes are
    in skills/improve-weather-answer next to this server.

    Self-contained: location resolution and the National Weather Service fetch
    happen inside this tool, one request per call, no background polling.
    US locations only.
    """
    days = max(1, min(int(days or 1), 8))

    async with httpx.AsyncClient(
        timeout=15.0, headers={"User-Agent": USER_AGENT}, follow_redirects=True
    ) as client:
        place = await _resolve_location(client, location, latitude, longitude)
        w = await _fetch_current(client, place["latitude"], place["longitude"])

    # The geocoded name is more precise than the NWS station's nearest town.
    if place.get("label"):
        w["city"] = place["label"]
    # The card shows the strip only when more than one day was asked for.
    w["days"] = (w.get("days") or [])[:days] if days > 1 else []

    when = datetime.now().strftime("%H:%M")
    where = f"{w['city']} - " if w.get("city") else ""
    text = (
        f"{where}{when} — {round(w['temperatureF'])}°F, {w['shortForecast']}, "
        f"{w['precipitationChance']}% chance of precipitation."
    )
    if w["days"]:
        outlook = "; ".join(
            f"{d['day']} {round(d['high'])}°/{d['precipitationChance']}%"
            for d in w["days"]
        )
        text += f" Outlook: {outlook}."

    # Paired with structured_output=True above, this dict becomes the result's
    # structuredContent -- which is the only thing the card can paint from.
    result: dict[str, Any] = {"text": text, "current_time": when, "local_weather": w}
    if extra_html and extra_html.strip():
        result["extra_html"] = extra_html
    return result


# --------------------------------------------------------------------------- #
# 3. The View: self-contained HTML/JS that runs in the host's sandboxed iframe.  #
# --------------------------------------------------------------------------- #
CARD_HTML = r"""
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
    <span class="temp" id="temp">—</span>
    <span class="time" id="time"></span>
  </div>
  <span class="cond"><span class="dot"></span><span id="cond">—</span></span>
  <div>
    <div class="precip"><span id="pct">0</span>% chance of precipitation</div>
    <div class="bar"><i id="fill"></i></div>
  </div>
  <div class="strip" id="strip" hidden></div>
</div>

<!-- Model-extension area: render_weather's optional `extra_html` lands here.
     Set via innerHTML, so script tags never execute -- presentational only. -->
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

    document.getElementById("temp").textContent = Math.round(w.temperatureF) + "\u00b0";
    document.getElementById("time").textContent =
      (w.city ? w.city + " \u00b7 " : "") + (data.current_time || "");
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

    // Model-extension area. innerHTML never executes <script>, so whatever
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
"""


# --------------------------------------------------------------------------- #
# 4. Registration. The card is served as text/html;profile=mcp-app so the host   #
#    can prefetch and security-review it before any tool runs. The server is     #
#    built last: MCPServer copies each extension's tools and resources at        #
#    construction, so anything registered afterwards never reaches the host.     #
# --------------------------------------------------------------------------- #
# The connect domains let the card's fallback fetch reach exactly these three
# services from inside the sandbox -- the host turns them into the iframe's
# CSP (visible as the connect-src query param on the mcp_apps URL).
apps.add_html_resource(
    UI_RESOURCE_URI,
    CARD_HTML,
    title="Weather card",
    csp=ResourceCsp(
        connect_domains=[
            "https://api.weather.gov",
            "https://geocoding-api.open-meteo.com",
            "https://ipapi.co",
        ]
    ),
)

mcp = MCPServer("weather-card", extensions=[apps])


if __name__ == "__main__":
    # MCPServer defaults to stdio transport, which is what Claude Desktop launches.
    mcp.run()
