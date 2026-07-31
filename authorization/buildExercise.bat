@echo off
REM buildExercise
::  Global commands for building exercise files.

if "%~1"=="--reset-workspace" (
 if not exist "%~dp0..\exercise-mcp.code-workspace" (
  echo Workspace file not found: "%~dp0..\exercise-mcp.code-workspace"
  goto :eof
 )
 echo Resetting Workspace
 REM Consume the comma ahead of the "mcp" block so "settings" does not end on a
 REM dangling comma, then close "settings" and the root object.
 sed -i -zE "s/,[[:space:]]*\"mcp\": \{.{1,}\"inputs\": \[\].{1,}\}/\n }\n}/" "%~dp0..\exercise-mcp.code-workspace"
 sed -i -E "s/\t/ /g" "%~dp0..\exercise-mcp.code-workspace"
)
