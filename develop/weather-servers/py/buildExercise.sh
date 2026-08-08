#!/bin/bash
# buildExercise
# Script for exercise, making a simple MCP server as hard as possible for learning purposes.

set -u

# Global variables.
_parOneBuildExercise="${1:-}"
_scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_optOut=0

_package() {
  cat > pyproject.toml <<'EOF'
[project]
name = "weather-server"
version = "0.1.0"
description = "A simple MCP weather server that renders a GUI from local conditions"
requires-python = ">=3.10"
dependencies = [
  "httpx2>=2.9",
  "mcp>=2.0.0rc1",
]

EOF
  # Server runs as a script, so nothing is built or installed as a package.
  cat >> pyproject.toml <<'EOF'
[tool.uv]
package = false
EOF
}

_main() {
  local _kind="$1"
  local _section="$2"
  local _target="$3"

  if [ "$_kind" = "helper-file" ]; then
    echo
    echo "Creating Server Helper Files:"
  elif [ "$_kind" = "server-file" ]; then
    echo
    echo "Creating 'server.py' File:"
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
  echo "Creating virtual environment and installing dependencies:"
  uv sync
  echo
  echo "The MCP client starts the server, so launch it from here only to test:"
  echo "  uv --directory \"$_scriptDir/weather-server\" run server.py"
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
      echo "Creating server project"
      echo
      mkdir -p "$_scriptDir/weather-server"
      cp -f "$_scriptDir/README.md" "$_scriptDir/weather-server/build_source.data.txt"
      cd "$_scriptDir/weather-server" || _closeOut 1
      mkdir -p assets gui utils
      cp -f "$_scriptDir"/../assets/*.svg assets/
      _runBuildExercise 1
      return
    elif [ "$_parOneBuildExercise" = "--reset" ]; then
      echo "Resetting Server:"
      rm -rf "$_scriptDir/weather-server"
      _closeOut 0
    else
      _optOut=1
      echo "Something unexpected happened"
      echo "Script only accepts the options:"
      _closeOut 1
    fi
  fi

  if [ "$1" = "1" ]; then
    echo "Making Local MCP Server Environment:"
    echo
    _package
    echo "Building Local MCP Server:"
    echo
    # build using parameters
    _main helper-file UTILS-MAKE-NWS-REQUEST "utils/make_nws_request.py"
    _main helper-file UTILS-FORMAT-ALERT "utils/format_alert.py"
    _main helper-file CATEGORIZE-LOCAL-WEATHER "utils/categorize_local_weather.py"
    _main helper-file GUI-RENDER-WEATHER "gui/gui_render_weather.py"
    _main helper-file GUI-DRAW-WEATHER "gui/gui_draw_weather.py"
    _main server-file SERVER "server.py"
    rm -f "$_scriptDir/weather-server/build_source.data.txt"
    _runBuildExercise 2
    return
  fi

  if [ "$1" = "2" ]; then
    echo "Running the server:"
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

  # change back to root of exercise-mcp
  # Only outlives the script when it is sourced, since a run script cannot
  # change the working directory of the shell that started it.
  # IMPORTANT - leave last
  cd "$_scriptDir/../../.." || true
  exit "${1:-0}"
}

cd "$_scriptDir" || exit 1
_runBuildExercise 0
