#!/bin/bash
# buildExercise
# Script for exercise, making a simple MCP server as hard as possible for learning purposes.

# Variable for this folder
_curDir="$(cd "$(dirname "$0")" && pwd)"
_ScriptName=$(basename "$0")

# Start in correct server folder
cd "$(dirname "$0")"

###### Support Functions #####
# Create pyproject.toml
function _packageToml {
 cat << PACKAGE
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
  "pydantic-settings>=2.5.2",
  "sse-starlette>=1.6.1",
  "uvicorn>=0.23.1; sys_platform != 'emscripten'",
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

# Create the server source files
function _main {
 if [ "$1" == "--stdout" ]; then
   echo && echo Creating Server Files:
   echo \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
   cat build_source.data.txt | sed -zE "s/--START_CONFIG--(.*)--END_CONFIG--.*/\1/" | sed 1d
   cat build_source.data.txt | sed -zE "s/.*--START_TOKEN-VERIFY--(.*)--END_TOKEN-VERIFY--.*/\1/" | sed 1d
   echo && echo Creating 'server.py' File:
   echo \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
   cat build_source.data.txt | sed -zE "s/.*--START_SERVER--(.*)--END_SERVER--.*/\1/" | sed 1d
 else
  cat build_source.data.txt | sed -zE "s/--START_CONFIG--(.*)--END_CONFIG--.*/\1/" | sed 1d > "$_curDir/mcp_server/config.py"
  cat build_source.data.txt | sed -zE "s/.*--START_TOKEN-VERIFY--(.*)--END_TOKEN-VERIFY--.*/\1/" | sed 1d > "$_curDir/mcp_server/token_verifier.py"
  cat build_source.data.txt | sed -zE "s/.*--START_SERVER--(.*)--END_SERVER--.*/\1/" | sed 1d > "$_curDir/mcp_server/server.py"
 fi
}

# Install and build
function _install {
 echo Handle virtual environment and dependencies
 uv sync
 echo Start resouce server on port 3000, connect to authorization server \(keycloak\)
 uv run mcp-simple-auth-rs --port=3000 --auth-server=http://localhost:8080 --transport=streamable-http
 # echo RFC 8707 strict resource validation
 # uv run mcp-simple-auth-rs --port=3000 --auth-server=http://localhost:8080 --transport=streamable-http --oauth-strict
 echo Test client with streamable HTTP
 MCP_SERVER_PORT=3000 MCP_TRANSPORT_TYPE=streamable-http uv run mcp-simple-auth-client
}

# Switch variable
_optOut=0
function _runBuildExercise {
 if [ "$1" == "--build" ]; then
  echo Creating server folder: && echo
  if [ ! -e "$_curDir/mcp_server" ]; then
   mkdir "$_curDir/mcp_server"
  fi
  echo Creating project, typing with skills like it is the 1980\'s.
  # Call functions
  echo Making \`pyproject.toml\` File: && echo
  _packageToml > pyproject.toml

  echo Preparing \`mcp_server\` Files: && echo
  _main --stdout
  _main --src

  echo Credentials live in mcp_server/config.py \(no .env file needed\).
  sed -i "s/<_KEYCLOAK_SERVER_ID_>/$_KEYCLOAK_ID/" mcp_server/config.py
  sed -i "s/<_KEYCLOAK_SERVER_SECRET_>/$_KEYCLOAK_SECRET/" mcp_server/config.py
  _install
 elif [ "$1" == "--reset" ]; then
  echo Resetting Server:
  rm -rf "$_curDir/mcp_server/" "$_curDir/.venv/" "$_curDir/pyproject.toml" "$_curDir/uv.lock"
  if [ -e "../../exercise-mcp.code-workspace" ]; then
   if [ -e "../$_ScriptName" ]; then
    bash "../$_ScriptName" "--reset-workspace"
   fi
  fi
 else
  _optOut=1
  echo Something unexpected happened
  echo Script only accepts the options:
 fi
}

# Run script main function
if [ "$1" != "" ]; then
 _runBuildExercise $1
else
 _optOut=1
 echo Something unexpected happened
 echo Script requires at least one option:
fi

if [ $_optOut -eq 1 ]; then
 echo \ \ --build
 echo \ \ --reset
fi

# Done
echo buildExercise Script Complete:
# Change back to root of exercise-mcp.
cd ../..
