# exercise-mcp

> [!NOTE]
> Work in Progress (WIP)

<details>

<summary>Show Details</summary>

> [!NOTE]
> AGENT NOTE: Ignore shorthand like:
> - `(update.needed, .*)=>`
> - `(markedPages.index, .*)=>`
> These will be handle towards the end of the exercise.

</details>

This is a learning exercise where I went past the copy/paste procedure from the
tutorials provided from
[Model Context Protocol](https://modelcontextprotocol.io/docs/getting-started/intro),
and made implementing the server and/or client as hard as possible. To do so, I
studied and manually typed the code like it was the year 2017.

## Authorizations

For the authorizations servers, I made it even tougher in order to get a better
understanding. Do do this I made a `buildExercise` script for each language.

**Getting Started**

Using Docker terminal:

```bash
docker run -p 127.0.0.1:8080:8080 -e KC_BOOTSTRAP_ADMIN_USERNAME=admin -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin quay.io/keycloak/keycloak start-dev
```

## Build Script

There are two portions for this exercise:

1. Authorization MCP Servers: [authorization](authorization)
2. Local MCP Servers: [develop](develop)

For each server in either portion there is a build script: `buildExercise`. It
can be called using either Windows or Linux. The script options are constant:

- `--build`: Build the server from raw data
- `--reset`: Put the server folder back in it's initial state

With the `authorization` servers having an additional constant option:

- `--secure`: Clear the `KEYCLOAK_SECRET` data from the authorization file

Some scripts may have there own option, depending on the language and how it
can be used per OS. This exercise was built on Windows, using Windows Subsystem
for Linux (*WSL*); so language specific options will resolve conflicts in
regards to that.

In addition to that, each portion will have a global script that will handle
functions and/or subroutines that can be utilized by each of portion's
language script.

### Authorization Server with TypeScript

See [ts-server](authorization/ts-server/README.md).

### Authorization Server with Python

See [py-server](authorization/py-server/README.md).

## LICENSE

MIT
