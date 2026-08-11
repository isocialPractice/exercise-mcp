#!/bin/bash
# buildExercise
# Script for exercise, making a simple MCP server as hard as possible for learning purposes.

set -u

# Global variables.
_parOneBuildExercise="${1:-}"
_scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_optOut=0

_package() {
  _main helper-file PACKAGE "package.json"
  _main helper-file TSCONFIG "tsconfig.json"
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
    echo "Creating 'src/index.ts' File:"
  else
    echo "Something unexpected happened"
    _closeOut 1
  fi
  echo "*************************************************************************"

  # The data file may carry CRLF endings, so strip them here and match markers
  # on the bare line. Written with awk rather than `sed -z` to stay portable to
  # the BSD sed that ships with macOS.
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
  echo "Installing dependencies and compiling:"
  npm install
  npm run build
  echo
  echo "The MCP client starts the server, so launch it from here only to test:"
  echo "  node \"$_scriptDir/weather-server/build/index.js\""
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
      mkdir -p assets src src/utils src/gui
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
    _main helper-file UTILS-MAKE-NWS-REQUEST "src/utils/makeNwsRequest.ts"
    _main helper-file UTILS-FORMAT-ALERT "src/utils/formatAlert.ts"
    _main helper-file CATEGORIZE-LOCAL-WEATHER "src/utils/categorizeLocalWeather.ts"
    _main helper-file GUI-RENDER-WEATHER "src/gui/guiRenderWeather.ts"
    _main helper-file GUI-DRAW-WEATHER "src/gui/guiDrawWeather.ts"
    _main helper-file GUI-WEATHER-CARD "src/gui/guiWeatherCard.ts"
    _main server-file SERVER "src/index.ts"
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
