#!/bin/bash
# buildExercise
# Script for exercise, making a simple MCP server as hard as possible for learning purposes.

set -u

# Global variables.
_parOneBuildExercise="${1:-}"
_curDir="$(cd "$(dirname "$0")" && pwd)"
_ScriptName="$(basename "$0")"
_optOut=0
# Windows restores the net9.0 package set, WSL restores net10.0.
_osVersion=10

_package() {
  _main PROTECTEDMCPSERVER "ProtectedMcpServer.csproj"
  # The README pins one framework, so retarget it to the major this side builds.
  sed -i "s|<TargetFramework>net[0-9]*\.0</TargetFramework>|<TargetFramework>net$_osVersion.0</TargetFramework>|" ProtectedMcpServer.csproj
}

_main() {
  local _section="$1"
  local _target="$2"

  echo
  if [ "$_target" = "Program.cs" ]; then
    echo "Creating 'Program.cs' File:"
  else
    echo "Creating Server Files:"
  fi
  echo "*************************************************************************"

  # The data file carries CRLF endings, so strip them here and match markers on
  # the bare line. Written with awk rather than `sed -z` so the CRLF copy of the
  # README extracts the same way under WSL as it does under Git Bash.
  # Each section wraps its code in a fence, so the captured lines are buffered
  # and the opening "```lang" and closing "```" are dropped on the way out.
  # Markers are matched whole, so the XML comments inside a block are left alone.
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
  # A client outside this VM cannot route to localhost here, so the public URL
  # advertised in the protected resource metadata has to be the VM address.
  # An address supplied by the caller always wins.
  if [ -z "${MCP_SERVER_URL:-}" ]; then
    _wslIp="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if [ -n "$_wslIp" ]; then
      MCP_SERVER_URL="http://$_wslIp:3000/"
    fi
  fi
  export MCP_SERVER_URL

  echo "Run Project Server"
  echo "Reachable at ${MCP_SERVER_URL:-http://localhost:3000/}"
  dotnet run --framework "net$_osVersion.0"
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
      echo "Creating project, copy pasted like its 2026"
      echo
      mkdir -p "$_curDir/Tools"
      cp -f "$_curDir/README.md" "$_curDir/build_source.data.txt"
      _runBuildExercise 1
      return
    elif [ "$_parOneBuildExercise" = "--reset" ]; then
      echo "Resetting Server:"
      rm -rf "$_curDir/Tools" "$_curDir/bin" "$_curDir/obj" "$_curDir/Program.cs" "$_curDir/ProtectedMcpServer.csproj"
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
    echo "Making \`ProtectedMcpServer.csproj\` File:"
    echo
    _package

    echo "Preparing \`server\` Files:"
    echo
    _main MATH-TOOL "Tools/MathTools.cs"
    _main SERVER "Program.cs"
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
