# Changelog

All notable changes to `exercise-mcp` are documented in this file.

**Version syntax**: `MM.DD.YYYY-unreleased` or `MM.DD.YYYY`

- `MM` -- two-digit month
- `DD` -- two-digit day
- `YYYY` -- four-digit year
- `unreleased` -- constant prefix while the project has no tagged releases

## [08.10.2026]

### Added

- `weather_card` tool on the ts weather server -- the weather-cards feature,
  a TypeScript port of the `modules/weather_card-py` interactive card (MCP
  Apps): resolves a location by name, coordinates, the
  `WEATHER_CARD_DEFAULT_LOCATION` default, or public IP, then fetches
  current conditions plus a day-by-day outlook (up to 8 days) from NWS and
  returns a text summary alongside the `structuredContent` the card paints
  from
- `ui://weather/card` resource on the ts server, served as
  `text/html;profile=mcp-app` with CSP connect domains limiting the card's
  in-iframe fallback fetch; the server now declares the `resources`
  capability with list/read handlers
- `src/gui/guiWeatherCard.ts` marker section in the ts README, with matching
  extraction lines in both `buildExercise` scripts

### Fixed

- ruby Gemfile pins `bigdecimal` to the default gem that ships with the
  interpreter, so `bundle install` no longer tries to compile a native
  extension on toolchain-less setups
- ruby "Add Server" registration rewritten for Claude Desktop, which does not
  apply a `cwd`: absolute `weather.rb` path plus `BUNDLE_GEMFILE` in the
  entry's `env` block

## [08.07.2026]

### Added

- `buildExercise.bat`/`.sh` pairs for the seven remaining weather-server
  languages (ts, csharp, go, java, kotlin, ruby, rust), extracting each
  project from its README marker sections
- Complete tutorial-variation READMEs for those seven languages: marker
  sections, the GUI styling variation, and Windows-flavored setup steps
- `repoPath` argument on `render_weather` (all ports except py), so a client
  can name the repository the styling directives apply to
- "Use With Claude" sections in every server README, covering Claude Code
  (`claude mcp add`) and Claude Desktop registration
- Folder gist READMEs documenting the shared design once:
  [develop](develop/README.md),
  [weather-servers](develop/weather-servers/README.md),
  [weather-clients](develop/weather-clients/README.md), and
  [modules](modules/README.md); root README gained "The Gist"
- `modules/weather-on-broadway` -- TypeScript MCP server staging forecasts as
  original showtunes, with a parsed songbook and marquee/stage SVG assets
- Toolchain bootstrap in the java and kotlin build scripts: Maven downloads
  into `.maven/` and Gradle into `.gradle-dist/` when not on `PATH`
- markedPages integration: `index.html` configured for this repository with
  MDX `<Tabs>`/`<CodeGroup>` tab rendering, `Label::path` menu entries, the
  `menuStyle` side/default menus, and folder-based `docPages` syntax;
  improvements plugged back into the markedPages repository
- MDX shorthand swept: all `(markedPages.index, ...)` comment blocks across
  the READMEs resolved into live `<CodeGroup>`/`<Tabs>` markup
- Portable prompt at `.claude/marked-pages.prompt.md` for applying the
  markedPages flow to similar folders

### Fixed

- csharp scripts: the `_OS_V_` placeholder substitution was a no-op; replaced
  with `_osVersion` retargeting of the extracted csproj (`net9.0` on Windows,
  `net10.0` on WSL)
- kotlin: `build.gradle.kts` missing its `repositories` block, and the server
  code migrated to the `kotlin-sdk` 0.9.0 API (types package,
  `asSource().buffered()` transport)
- java: builds without a global Maven, and `JAVA_HOME` derives from `java` on
  `PATH` when unset
- authorization py-server `buildExercise.sh` rebuilt on the marker-extraction
  pattern to match its `.bat` sibling
- Menu validation on localhost checks the local checkout instead of the
  pushed GitHub tree, so unpushed folders appear while developing

## [08.06.2026-unreleased]

### Added

- Python weather server and client exercises completed, including their
  `buildExercise` scripts and the GUI variation (categorize, render, draw)

## [08.02.2026-unreleased]

### Added

- `modules/` folder for tinkering, starting with `weather_card-py` -- an
  interactive weather card rendered inside Claude Desktop

## [07.31.2026-unreleased]

### Added

- Initial exercises: authorization MCP servers (TypeScript, Python, C#) with
  `buildExercise` scripts and the Keycloak flow, and the `develop` weather
  server/client tutorial folders
- markedPages template copied in as `index.html`
