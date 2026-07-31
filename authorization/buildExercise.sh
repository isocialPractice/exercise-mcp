#!/bin/bash
# buildExercise
# Global commands for building exercise files.

_curDir="$(cd "$(dirname "$0")" && pwd)"
_workspace="$_curDir/../exercise-mcp.code-workspace"

# Eight hex characters, matching the style VS Code uses for generated keys.
_serverId() {
 od -An -N4 -tx1 /dev/urandom | tr -d ' \n'
}

# Points the workspace MCP client at a url, adding the whole "mcp" block when
# the workspace does not carry one yet.
_setWorkspaceServer() {
 _url="$1"

 if [ -z "$_url" ]; then
  echo Missing url for --set-workspace-server
  return 1
 fi

 if [ ! -e "$_workspace" ]; then
  echo Workspace file not found: "$_workspace"
  return 1
 fi

 if grep -q '"mcp"' "$_workspace"; then
  sed -i -E "s#http://[a-zA-Z0-9._-]+:[0-9]+/?#$_url#" "$_workspace"
  echo Workspace MCP url set to "$_url"
  return 0
 fi

 _name="wsl-mcp-server-$(_serverId)"

 # Follow whichever indent character the workspace already uses, since
 # --reset-workspace rewrites tabs to spaces.
 if grep -q "$(printf '\t')" "$_workspace"; then
  _i="$(printf '\t')"
 else
  _i=' '
 fi
 _i2="$_i$_i"
 _i3="$_i2$_i"
 _i4="$_i3$_i"
 _i5="$_i4$_i"

 _block="$_i2\"mcp\": {
$_i3\"servers\": {
$_i4\"$_name\": {
$_i5\"url\": \"$_url\",
$_i5\"type\": \"http\"
$_i4}
$_i3},
$_i3\"inputs\": []
$_i2}"

 # "settings" closes on the next to last brace of the file. The entry ahead of
 # it needs a comma once another key follows it.
 awk -v block="$_block" '
  { line[NR] = $0 }
  END {
   rootClose = NR
   while (rootClose > 1 && line[rootClose] ~ /^[[:space:]]*$/) rootClose--
   settingsClose = rootClose - 1
   while (settingsClose > 1 && line[settingsClose] ~ /^[[:space:]]*$/) settingsClose--

   for (i = 1; i <= NR; i++) {
    if (i == settingsClose - 1) { print line[i] ","; continue }
    if (i == settingsClose) { print block; print line[i]; continue }
    print line[i]
   }
  }
 ' "$_workspace" > "$_workspace.tmp" && mv "$_workspace.tmp" "$_workspace"

 echo Added workspace MCP server "$_name" at "$_url"
}

# Use POSIX '=' so the test works when invoked by dash/sh, not just bash.
if [ "$1" = "--reset-workspace" ]; then
 if [ -e "$_workspace" ]; then
  echo Resetting Workspace
  # Consume the comma ahead of the "mcp" block so "settings" does not end on a
  # dangling comma, then close "settings" and the root object.
  sed -i -zE "s/,[[:space:]]*\"mcp\": \{.{1,}\"inputs\": \[\].{1,}\}/\n }\n}/" "$_workspace"
  sed -i -E "s/\t/ /g" "$_workspace"
 else
  echo Workspace file not found: "$_workspace"
 fi
elif [ "$1" = "--set-workspace-server" ]; then
 _setWorkspaceServer "$2"
else
 echo Unexpected incorrect use:
 echo Options expeected:
 echo \ \ --reset-workspace
 echo \ \ --set-workspace-server \<url\>
fi
