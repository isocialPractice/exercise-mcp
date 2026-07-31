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
 cat project.txt >    "$_curDir/ProtectedMcpServer.csproj"
 sed -i "s/_OS_V_/10/" "$_curDir/ProtectedMcpServer.csproj"
}

# Create the server source files
function _main {
 if [ "$1" == "--stdout" ]; then
   echo && echo Creating Server Files:
   echo \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
   cat build_source.data.txt | sed -zE "s/--START_MATH-TOOL--(.*)--END_MATH-TOOL--.*/\1/" | sed 1d
   echo && echo Creating 'server.py' File:
   echo \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
   cat build_source.data.txt | sed -zE "s/.*--START_SERVER--(.*)--END_SERVER--.*/\1/" | sed 1d
 else
  cat build_source.data.txt | sed -zE "s/--START_MATH-TOOL--(.*)--END_MATH-TOOL--.*/\1/" | sed 1d > "$_curDir/Tools/MathTools.cs"
  cat build_source.data.txt | sed -zE "s/.*--START_SERVER--(.*)--END_SERVER--.*/\1/" | sed 1d > "$_curDir/Program.cs"
 fi
}

# Install and build
function _install {
  # A client outside this VM cannot route to localhost here, so the public URL
  # advertised in the protected resource metadata has to be the VM address.
  # An address supplied by the caller always wins.
  if [ -z "$MCP_SERVER_URL" ]; then
   _wslIp="$(hostname -I 2>/dev/null | awk '{print $1}')"
   if [ -n "$_wslIp" ]; then
    MCP_SERVER_URL="http://$_wslIp:3000/"
   fi
  fi
  export MCP_SERVER_URL

  echo Run Project Server
  echo Reachable at "${MCP_SERVER_URL:-http://localhost:3000/}"
  dotnet run --framework net10.0
}

# Switch variable
_optOut=0
function _runBuildExercise {
 if [ "$1" == "--build" ]; then
  echo Creating server folder: && echo
  if [ ! -e "$_curDir/Tools" ]; then
   mkdir "$_curDir/Tools"
  fi
  echo Creating project, copy pasted like its 2026.
  # Call functions
  echo Making \`ProtectedMcpServer.csproj\` File: && echo
  _packageToml

  echo Preparing \`server\` Files: && echo
  _main --stdout
  _main --src
  _install
 elif [ "$1" == "--reset" ]; then
  echo Resetting Server:
  rm -rf "$_curDir/Tools/" "$_curDir/bin/" "$_curDir/obj/" "$_curDir/Program.cs" "$_curDir/ProtectedMcpServer.csproj"
  # rm -rf "$_curDir/mcp_server/" "$_curDir/.venv/" "$_curDir/pyproject.toml" "$_curDir/uv.lock"
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
