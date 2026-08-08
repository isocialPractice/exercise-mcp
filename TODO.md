# `exercise-mcp` TODO

> [!NOTE]
> AGENT NOTE: Ignore shorthand like:
> - `(update.needed, .*)=>`
> - `(markedPages.index, .*)=>`

## Current

- [ ] Make minor variation of weather example from
 [modelcontextprotocol.io/develope](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server),
 and plug into:
  - [x] Python: [vscode-py_maze](https://github.com/isocialPractice/vscode-py_maze/tree/local-weather)
    - [x] Add local `task.bat` script
  - [ ] TypeScript: [vscode-emailClient](https://github.com/isocialPractice/vscode-emailClient)
    - [x] Add local `task.bat` script
  - [x] Java: [esp32-fetch-data](https://github.com/jhauga/esp32-fetch-data/tree/local-weather)
    - [x] Add local `task.bat` script
  - [x] Kotlin: [pilot-matter](https://github.com/isocialPractice/pilot-matter/tree/local-weather)
    - [x] Add local `task.bat` script
  - [x] C#: [ccal](https://github.com/jhauga/ccal/tree/local-weather)
    - [x] Add local `task.bat` script
  - [ ] Ruby: [street-crime](https://github.com/isocialPractice/street-crime)
    - [x] Add local `task.bat` script
  - [x] Rust: [napkin-sketch](https://github.com/isocialPractice/napkin-sketch/tree/local-weather)
    - [x] Add local `task.bat` script
  - [x] Go: [vscode-flight-map](https://github.com/isocialPractice/vscode-flight-map/tree/local-weather)
    - [x] Add local `task.bat` script

## Next

- [x] Variation, but style format responses in rythmic style of popular
 broadway songs, depending on how the current weather forecast is returned
  - See [modules/weather-on-broadway](modules/weather-on-broadway/README.md)

## Finalize

- [x] Complete [README.md](README.md)
- [x] Use [markedPages](https://github.com/jhauga/markedPages)
  - [x] Improve from here
    - **Shorthand**: `(markedPages.index, add.mdx.langTabSelect)=>{<prompt>}`
    - Resolved: MDX `<Tabs>`/`<CodeGroup>` tab rendering in [index.html](index.html)
  - [x] Plug improvements back into repository at [`GitHub\markedPages`](https://github.com/jhauga/markedPages)
  - Portable prompt for similar folders: [.claude/marked-pages.prompt.md](.claude/marked-pages.prompt.md)
- [ ] Plug into [practicing.xyz](https://practicing.xyz)

## Complete

- [x] Resolve Python server
  - See ~[_temp.txt](_temp.txt)~
  - See [authorization/resolve-server.md](authorization/resolve-server.md)
- [x] More liberal approach to `authorization` servers with other languages
- [x] Add a build workflow to make `docs` from each `README.md` per server
- [x] Complete reading

## During Process

- Draft `README.md`
- Draft notes for page `AI/MCP.html`
  - Determine: XML or Markdown
