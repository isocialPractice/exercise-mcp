#!/bin/bash
# buildExercise
# Script for exercise, making a simple MCP client as hard as possible for learning purposes.

set -u

# Global variables.
_parOneBuildExercise="${1:-}"
_scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_serverDir="$_scriptDir/../../weather-servers/py"
_optOut=0

_package() {
  # The key stays in the environment, so only its value is written to disk.
  if [ -z "${_WEATHER_CLIENT_KEY:-}" ]; then
    echo "Warning: _WEATHER_CLIENT_KEY is not set, so .env gets an empty key" >&2
  fi
  printf 'ANTHROPIC_API_KEY=%s\n' "${_WEATHER_CLIENT_KEY:-}" > .env
}

_main() {
  local _kind="$1"
  local _section="$2"
  local _target="$3"

  if [ "$_kind" = "helper-file" ]; then
    echo
    echo "Creating Helper File:"
  elif [ "$_kind" = "client-file" ]; then
    echo
    echo "Creating 'client.py' File:"
  else
    echo "Something unexpected happened"
    _closeOut 1
  fi
  echo "*************************************************************************"

  # The data file carries CRLF endings, so strip them here and match markers on
  # the bare line. Written with awk rather than `sed -z` to stay portable to the
  # BSD sed that ships with macOS.
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

_run() {
  echo "Remove boilerplate files"
  echo
  rm -f main.py
  echo "Creating virtual environment and installing dependencies:"
  echo
  # pyproject.toml already pins mcp, anthropic and python-dotenv, so sync
  # installs them instead of uv add rewriting the file that was just built.
  uv sync
  echo
  echo "Running Client:"
  # The client launches the server itself, so the server has to exist first.
  if [ ! -d "$_serverDir/weather-server" ]; then
    bash "$_serverDir/buildExercise.sh" --build
  fi
  uv run client.py "$_serverDir/weather-server/server.py"
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
      echo "Creating client project"
      echo
      mkdir -p "$_scriptDir/weather-client"
      uv init "$_scriptDir/weather-client"
      cp -f "$_scriptDir/README.md" "$_scriptDir/weather-client/build_source.data.txt"
      cd "$_scriptDir/weather-client" || _closeOut 1
      _runBuildExercise 1
      return
    elif [ "$_parOneBuildExercise" = "--reset" ]; then
      echo "Resetting Client:"
      rm -rf "$_scriptDir/weather-client"
      _closeOut 0
    else
      _optOut=1
      echo "Something unexpected happened"
      echo "Script only accepts the options:"
      _closeOut 1
    fi
  fi

  if [ "$1" = "1" ]; then
    echo "Making Local MCP Client Environment:"
    echo
    _package
    echo "Building Local MCP Client:"
    echo
    # build using parameters
    _main client-file CLIENT "client.py"
    _main helper-file PYPROJECT "pyproject.toml"
    rm -f "$_scriptDir/weather-client/build_source.data.txt"
    _runBuildExercise 2
    return
  fi

  if [ "$1" = "2" ]; then
    echo "Running the client:"
    _run
    echo "buildExercise Script Complete:"
    _closeOut 0
  fi
}

_closeOut() {
  # IMPORTANT - leave last
  if [ "$_optOut" = "1" ]; then
    echo "  --build"
    echo "  --reset"
  fi

  if [ "$_parOneBuildExercise" = "--build" ]; then
    # reset the server and this client
    # Run as separate processes so neither --reset re-enters this branch.
    bash "${BASH_SOURCE[0]}" --reset
    bash "$_serverDir/buildExercise.sh" --reset
  fi

  # change back to root of exercise-mcp
  # Only outlives the script when it is sourced, since a run script cannot
  # change the working directory of the shell that started it.
  # IMPORTANT - leave last
  cd "$_scriptDir/../../.." || true
  exit "${1:-0}"
}

cd "$_scriptDir" || exit 1
_runBuildExercise 0
