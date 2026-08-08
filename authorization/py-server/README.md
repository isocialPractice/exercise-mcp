# Python Authorization Server

A simple MCP resource server that validates OAuth tokens against a local
Keycloak authorization server via RFC 7662 token introspection, and exposes two
authenticated tools: `add_numbers` and `multiply_numbers`.

## Get Started

### Set OS Variables

See [authorization/README.md](../README.md)

### Install `uv`

See also [uv/installation](https://docs.astral.sh/uv/getting-started/installation/#winget)

```batch
winget install --id=astral-sh.uv -e
```

### Server Files and Folders

Since this is an exercise, the server source files are not checked in ready to
run. The project structure is generated from `build_source.data.txt` by the
`buildExercise` script.

> [!NOTE]
> The build script uses `sed`. On Windows, ensure a `sed` binary is on `PATH`
> (for example via [Cygwin](https://www.cygwin.com/)).

<CodeGroup>

```bash macOS/Linux
# Enusre to change to this folder.
cd authorization/<server-folder>
# Run the script
./buildExercise.sh --build
```

```batch Windows
:: Ensure you change to this folder.
cd authorization\<server-folder>
:: Run the script (generates files, runs `uv sync`, starts the server)
buildExercise.bat --build
```

</CodeGroup>

Use `--reset` to remove all generated files and return `py-server` to its
original state:

```batch
buildExercise.bat --reset
```

### Configuration (no `.env` file)

This server does **not** use a `.env` file. Everything the TypeScript sample kept
in `.env` lives directly in [mcp_server/config.py](mcp_server/config.py) as a
class attribute: host, port, auth server location, and the OAuth client id and
secret. Environment variables of the same name still override a default when set,
but nothing has to be exported for the server to run.

Set the OAuth client id and secret to match the confidential client you created
in Keycloak (see the setup guide). The client id must be the same client whose
secret you paste, or introspection is rejected with `401`:

```python
# mcp_server/config.py
OAUTH_CLIENT_ID: str = os.getenv("OAUTH_CLIENT_ID", "test-client")
OAUTH_CLIENT_SECRET: str = os.getenv("OAUTH_CLIENT_SECRET", "<your-client-secret>")
```

## Python MCP Authorization Server

### `pyproject.toml`

```toml
[project]
name = "mcp-simple-auth"
version = "0.1.0"
description = "A simple MCP server demonstrating OAuth authentication"
requires-python = ">=3.10"
authors = [{ name = "Model Context Protocol a Series of LF Projects, LLC." }]
license = { text = "MIT" }
dependencies = [
  "httpx>=0.27",
  "mcp>=2.0.0rc1",
  "pydantic>=2.0",
]

[project.scripts]
mcp-simple-auth-rs = "mcp_server.server:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["mcp_server"]

[dependency-groups]
dev = ["pyright>=1.1.391", "pytest>=8.3.4", "ruff>=0.8.5"]
```

### `config.py`
<!--START_CONFIG-->
```python
"""Configuration settings for the MCP auth server."""

import os


class Config:
    """Configuration class that loads from environment variables with sensible defaults."""

    # Server settings
    HOST: str = os.getenv("HOST", "localhost")
    PORT: int = int(os.getenv("PORT", "3000"))

    # Auth server settings
    AUTH_HOST: str = os.getenv("AUTH_HOST", "localhost")
    AUTH_PORT: int = int(os.getenv("AUTH_PORT", "8080"))
    AUTH_REALM: str = os.getenv("AUTH_REALM", "master")

    # OAuth client settings
    OAUTH_CLIENT_ID: str = os.getenv("OAUTH_CLIENT_ID", "<_KEYCLOAK_SERVER_ID_>")
    OAUTH_CLIENT_SECRET: str = os.getenv("OAUTH_CLIENT_SECRET", "<_KEYCLOAK_SERVER_SECRET_>")

    # Scope required on every token
    MCP_SCOPE: str = os.getenv("MCP_SCOPE", "mcp:tools")

    @property
    def server_url(self) -> str:
        """Build the server URL."""
        return f"http://{self.HOST}:{self.PORT}"

    @property
    def auth_base_url(self) -> str:
        """Build the auth server base URL."""
        return f"http://{self.AUTH_HOST}:{self.AUTH_PORT}/realms/{self.AUTH_REALM}/"


# Global configuration instance
config = Config()
```
<!--END_CONFIG-->

### `token_verifier.py`
<!--START_TOKEN-VERIFY-->
```python
"""Token verifier implementation using OAuth 2.0 Token Introspection (RFC 7662)."""

import logging
from typing import Any

import httpx2

from mcp.server.auth.provider import AccessToken, TokenVerifier
from mcp.shared.auth_utils import check_resource_allowed, resource_url_from_server_url

logger = logging.getLogger(__name__)


class IntrospectionTokenVerifier(TokenVerifier):
    """Token verifier that uses OAuth 2.0 Token Introspection (RFC 7662)."""

    def __init__(
        self,
        introspection_endpoint: str,
        server_url: str,
        client_id: str,
        client_secret: str,
    ):
        self.introspection_endpoint = introspection_endpoint
        self.server_url = server_url
        self.client_id = client_id
        self.client_secret = client_secret
        self.resource_url = resource_url_from_server_url(server_url)

    async def verify_token(self, token: str) -> AccessToken | None:
        """Verify token via introspection endpoint."""
        if not self.introspection_endpoint.startswith(("https://", "http://localhost", "http://127.0.0.1")):
            return None

        timeout = httpx2.Timeout(10.0, connect=5.0)
        limits = httpx2.Limits(max_connections=10, max_keepalive_connections=5)

        async with httpx2.AsyncClient(
            timeout=timeout,
            limits=limits,
            verify=True,
        ) as client:
            try:
                form_data = {
                    "token": token,
                    "client_id": self.client_id,
                }
                # Only send client_secret when one is configured
                # Public clients authenticate with client_id alone.
                if self.client_secret:
                    form_data["client_secret"] = self.client_secret
                headers = {"Content-Type": "application/x-www-form-urlencoded"}

                response = await client.post(
                    self.introspection_endpoint,
                    data=form_data,
                    headers=headers,
                )

                if response.status_code != 200:
                    return None

                data = response.json()
                if not data.get("active", False):
                    return None

                if not self._validate_resource(data):
                    return None

                return AccessToken(
                    token=token,
                    client_id=data.get("client_id", "unknown"),
                    scopes=data.get("scope", "").split() if data.get("scope") else [],
                    expires_at=data.get("exp"),
                    # AccessToken.resource is `str | None`. Keycloak returns `aud`
                    # as a *list* here (e.g. ["test-client", "http://localhost:3000",
                    # "account"]); passing that list straight in raises a pydantic
                    # ValidationError that the broad `except` below turns into a
                    # silent 401. We already confirmed this server's resource is a
                    # valid audience in `_validate_resource`, so record that.
                    resource=self.resource_url,
                    subject=data.get("sub"),  # RFC 7662 subject (resource owner)
                    claims=data,
                )

            except Exception:
                logger.exception("Token introspection failed")
                return None

    def _validate_resource(self, token_data: dict[str, Any]) -> bool:
        """Validate token was issued for this resource server.

        Rules:
        - Reject if 'aud' missing.
        - Accept if any audience entry matches the derived resource URL.
        - Supports string or list forms per JWT spec.
        """
        if not self.server_url or not self.resource_url:
            return False

        aud: list[str] | str | None = token_data.get("aud")
        if isinstance(aud, list):
            return any(self._is_valid_resource(a) for a in aud)
        if isinstance(aud, str):
            return self._is_valid_resource(aud)
        return False

    def _is_valid_resource(self, resource: str) -> bool:
        """Check if the given resource matches our server."""
        return check_resource_allowed(requested_resource=self.resource_url, configured_resource=resource)
```
<!--END_TOKEN-VERIFY-->

### `server.py`
<!--START_SERVER-->
```python
import datetime
import logging
from typing import Any
from urllib.parse import urljoin

from pydantic import AnyHttpUrl

from mcp.server import MCPServer
from mcp.server.auth.settings import AuthSettings

from .config import config
from .token_verifier import IntrospectionTokenVerifier

logger = logging.getLogger(__name__)


def create_oauth_urls() -> dict[str, str]:
    """Create OAuth URLs based on configuration (Keycloak-style)."""
    auth_base_url = config.auth_base_url

    return {
        "issuer": auth_base_url,
        "introspection_endpoint": urljoin(auth_base_url, "protocol/openid-connect/token/introspect"),
        "authorization_endpoint": urljoin(auth_base_url, "protocol/openid-connect/auth"),
        "token_endpoint": urljoin(auth_base_url, "protocol/openid-connect/token"),
    }


def create_server() -> MCPServer:
    """Create and configure the MCP server."""

    oauth_urls = create_oauth_urls()

    token_verifier = IntrospectionTokenVerifier(
        introspection_endpoint=oauth_urls["introspection_endpoint"],
        server_url=config.server_url,
        client_id=config.OAUTH_CLIENT_ID,
        client_secret=config.OAUTH_CLIENT_SECRET,
    )

    app = MCPServer(
        name="MCP Resource Server",
        instructions="Resource Server that validates tokens via Authorization Server introspection",
        debug=True,
        token_verifier=token_verifier,
        auth=AuthSettings(
            issuer_url=AnyHttpUrl(oauth_urls["issuer"]),
            required_scopes=[config.MCP_SCOPE],
            resource_server_url=AnyHttpUrl(config.server_url),
        ),
    )

    @app.tool()
    async def add_numbers(a: float, b: float) -> dict[str, Any]:
        """
        Add two numbers together.
        This tool demonstrates basic arithmetic operations with OAuth authentication.

        Args:
            a: The first number to add
            b: The second number to add
        """
        result = a + b
        return {
            "operation": "addition",
            "operand_a": a,
            "operand_b": b,
            "result": result,
            "timestamp": datetime.datetime.now().isoformat(),
        }

    @app.tool()
    async def multiply_numbers(x: float, y: float) -> dict[str, Any]:
        """
        Multiply two numbers together.
        This tool demonstrates basic arithmetic operations with OAuth authentication.

        Args:
            x: The first number to multiply
            y: The second number to multiply
        """
        result = x * y
        return {
            "operation": "multiplication",
            "operand_x": x,
            "operand_y": y,
            "result": result,
            "timestamp": datetime.datetime.now().isoformat(),
        }

    return app


def main() -> int:
    """
    Run the MCP Resource Server.

    This server:
    - Provides RFC 9728 Protected Resource Metadata
    - Validates tokens via Authorization Server introspection
    - Serves MCP tools requiring authentication

    Configuration is loaded from config.py and environment variables.
    """
    logging.basicConfig(level=logging.INFO)

    oauth_urls = create_oauth_urls()

    try:
        mcp_server = create_server()

        logger.info("Starting MCP Server on %s:%s", config.HOST, config.PORT)
        logger.info("Authorization Server: %s", oauth_urls["issuer"])

        mcp_server.run(
            transport="streamable-http",
            host=config.HOST,
            port=config.PORT,
            streamable_http_path="/",
        )
        return 0

    except Exception:
        logger.exception("Server error")
        return 1


if __name__ == "__main__":
    exit(main())
```
<!--END_SERVER-->

## Starting the Server

The `buildExercise --build` step already starts the server. To build and run it
manually:

```bash
# Either OS
uv sync
uv run mcp-simple-auth-rs --port=3000 --auth-server=http://localhost:8080 --transport=streamable-http
```

A healthy server answers an unauthenticated request with `401` (it is up and
asking for a token):

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/
```

### Connect to Client

Assuming the instructions from
[authorization](https://modelcontextprotocol.io/docs/tutorials/security/authorization)
have been followed, in VS Code do:

1. Press `Ctrl + Shift + P`
2. Type and select `MCP: List Server`
  - If not listed do:
    - `Ctrl + Shift + P`
    - Type and select `MCP: Add server`
    - Select `HTTP`
    - Input `http://localhost:3000`
    - Then follow steps 1-3
3. Select the MCP Server

VS Code will prompt to open the browser, allow, login, and the MCP tools will
be registered.

> [!NOTE]
> If a `.vscode` folder exists, an additional `settings.json` file may be created
> with contents like:

```json
{
 "chat.mcp.serverSampling": {
  "py-server/.vscode/mcp.json: my-mcp-server-f51abc5f": {
   "allowedModels": [
    "copilotcli/auto",
    "copilot/auto",
    "copilotcli/claude-haiku-4.5"
   ]
  }
 }
}
```

## Troubleshooting

- Try `Ctrl + Shift + P` then:
  - `Authentication: Remove Dynamic Authentication Providers`
  - Select the relevant `MCP Resource Server` and click **OK** to delete
- Ensure the server is running (`uv run mcp-simple-auth-rs ...`), and that the
  terminal stays open.

### Introspection returns `401` / server returns `500`

The most common cause is a client mismatch. Confirm in
[mcp_server/config.py](mcp_server/config.py):

- `OAUTH_CLIENT_ID` matches the confidential client in Keycloak (for example
  `test-client`), and
- `OAUTH_CLIENT_SECRET` is that client's **Credentials -> Client Secret**.

Then restart the server. Unlike the TypeScript sample, the Python server needs no
`new URL` audience patch: `check_resource_allowed` uses `urlparse`, which
tolerates non-URL audiences (such as `account` and `test-client`) instead of
throwing.

### Trusted Hosts URIs

> [!NOTE]
> Do not prepend the URI with the `http` protocol.

After getting the computer's IP from running `ifconfig` (*Linux*) or `ipconfig`
(*Windows*), the Trusted Hosts should look like:

```
localhost:*
172.17.0.1
172.17.80.1
```
