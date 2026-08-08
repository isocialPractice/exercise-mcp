#!/bin/bash
# buildExercise
# Script for exercise, making a simple MCP server as hard as possible for learning purposes.

set -u

# Global variables.
_parOneBuildExercise="${1:-}"
_curDir="$(cd "$(dirname "$0")" && pwd)"
_ScriptName="$(basename "$0")"
_optOut=0

_package() {
  cat > pyproject.toml <<'PACKAGE'
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
PACKAGE
}

_main() {
  local _section="$1"
  local _target="$2"

  echo
  if [ "$_target" = "mcp_server/server.py" ]; then
    echo "Creating 'server.py' File:"
  else
    echo "Creating Server Files:"
  fi
  echo "*************************************************************************"

  # The data file carries CRLF endings, so strip them here and match markers on
  # the bare line. Written with awk rather than `sed -z` so the CRLF copy of the
  # README extracts the same way under WSL as it does under Git Bash.
  # Each section wraps its code in a fence, so the captured lines are buffered
  # and the opening "```lang" and closing "```" are dropped on the way out.
  awk -v section="$_section" '
    { sub(/\r$/, "") }
    $0 == "<!--START_" section "-->" { capture = 1; next }
    $0 == "<!--END_" section "-->"   { capture = 0 }
    capture { lines[++count] = $0 }
    END {
      if (count < 3) {
        print "Section " section " not found in build_source.data.txt" > "/dev/stderr"
        exit 1
      }
      for (i = 2; i < count; i++) print lines[i]
    }
  ' build_source.data.txt > "$_target" || _closeOut 1
}

_install() {
  echo "Handle virtual environment and dependencies"
  uv sync
  echo "Start resouce server on port 3000, connect to authorization server (keycloak)"
  # Port and auth server now come from mcp_server/config.py.
  # uv run mcp-simple-auth-rs --port=3000 --auth-server=http://localhost:8080 --transport=streamable-http
  uv run mcp-simple-auth-rs
  # echo RFC 8707 strict resource validation
  # uv run mcp-simple-auth-rs --port=3000 --auth-server=http://localhost:8080 --transport=streamable-http --oauth-strict
  # echo Test client with streamable HTTP
  # MCP_SERVER_PORT=3000 MCP_TRANSPORT_TYPE=streamable-http uv run mcp-simple-auth-client
}

_runBuildExercise() {
  if [ "$1" = "0" ]; then
    if [ -z "$_parOneBuildExercise" ]; then
      _optOut=1
      echo "Something unexpected happened"
      echo "Script requires at least one option:"
      _closeOut 1
    fi

    if [ "$_parOneBuildExercise" = "--build" ]; then
      echo "Creating project, typing with skills like it is the 1980's."
      echo
      mkdir -p "$_curDir/mcp_server"
      cp -f "$_curDir/README.md" "$_curDir/build_source.data.txt"
      _runBuildExercise 1
      return
    elif [ "$_parOneBuildExercise" = "--reset" ]; then
      echo "Resetting Server:"
      rm -rf "$_curDir/mcp_server" "$_curDir/.venv" "$_curDir/pyproject.toml" "$_curDir/uv.lock"
      if [ -e "$_curDir/../../exercise-mcp.code-workspace" ]; then
        if [ -e "$_curDir/../$_ScriptName" ]; then
          bash "$_curDir/../$_ScriptName" --reset-workspace
        fi
      fi
      _closeOut 0
    else
      _optOut=1
      echo "Something unexpected happened"
      echo "Script only accepts the options:"
      _closeOut 1
    fi
  fi

  if [ "$1" = "1" ]; then
    echo "Making \`pyproject.toml\` File:"
    echo
    _package

    echo "Preparing \`server.py\` File:"
    echo
    _main CONFIG "mcp_server/config.py"
    _main TOKEN-VERIFY "mcp_server/token_verifier.py"
    _main SERVER "mcp_server/server.py"

    echo "Credentials live in mcp_server/config.py (no .env file needed)."
    if [ -z "${_KEYCLOAK_ID:-}" ] || [ -z "${_KEYCLOAK_SECRET:-}" ]; then
      echo "Warning: _KEYCLOAK_ID or _KEYCLOAK_SECRET is not set, so config.py gets blank credentials" >&2
    fi
    # Substitute on "|" so a secret carrying a slash cannot close the expression.
    sed -i "s|<_KEYCLOAK_SERVER_ID_>|${_KEYCLOAK_ID:-}|" mcp_server/config.py
    sed -i "s|<_KEYCLOAK_SERVER_SECRET_>|${_KEYCLOAK_SECRET:-}|" mcp_server/config.py
    _runBuildExercise 2
    return
  fi

  if [ "$1" = "2" ]; then
    echo "Building and starting the server:"
    _install
    echo "buildExercise Script Complete:"
    _closeOut 0
  fi
}

_closeOut() {
  rm -f "$_curDir/build_source.data.txt"

  # IMPORTANT - leave last
  if [ "$_optOut" = "1" ]; then
    echo "  --build"
    echo "  --reset"
  fi

  # change back to root of exercise-mcp
  # Only outlives the script when it is sourced, since a run script cannot
  # change the working directory of the shell that started it.
  # IMPORTANT - leave last
  cd "$_curDir/../.." || true
  exit "${1:-0}"
}

cd "$_curDir" || exit 1
_runBuildExercise 0
