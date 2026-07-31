@echo off
rem buildExercise
::  Script for exercise, making a simple MCP server as hard as possible for learning purposes.

:; Global variables.
set "_parOneBuildExercise=%~1"
set "_checkParOneBuildExercise=-%_parOneBuildExercise%-"

cd /D "%~dp0"
call :_runBuildExercise 0
goto:eof

:_package
 if "%1"=="1" (
  echo [project]> pyproject.toml
  echo name ^= "mcp-simple-auth">> pyproject.toml
  echo version ^= "0.1.0">> pyproject.toml
  echo description ^= "A simple MCP server demonstrating OAuth authentication">> pyproject.toml
  echo requires-python ^= ">=3.10">> pyproject.toml
  echo authors ^= [{ name = "Model Context Protocol a Series of LF Projects, LLC." }]>> pyproject.toml
  echo license ^= { text = "MIT" }>> pyproject.toml
  echo dependencies ^= [>> pyproject.toml
  echo   "httpx>=0.27",>> pyproject.toml
  echo   "mcp>=2.0.0rc1",>> pyproject.toml
  echo   "pydantic>=2.0",>> pyproject.toml
  echo ]>> pyproject.toml
  echo:>> pyproject.toml
  echo [project.scripts]>> pyproject.toml
  echo mcp-simple-auth-rs ^= "mcp_server.server:main">> pyproject.toml
  echo:>> pyproject.toml
  echo [build-system]>> pyproject.toml
  echo requires ^= ["hatchling"]>> pyproject.toml
  echo build-backend ^= "hatchling.build">> pyproject.toml
  echo:>> pyproject.toml
  echo [tool.hatch.build.targets.wheel]>> pyproject.toml
  echo packages ^= ["mcp_server"]>> pyproject.toml
  echo:>> pyproject.toml
  echo [dependency-groups]>> pyproject.toml
  echo dev ^= ["pyright>=1.1.391", "pytest>=8.3.4", "ruff>=0.8.5"]>> pyproject.toml
 )
goto:eof

:_main
 if "%1"=="1" (
  echo: & echo Creating Server Files:
  echo *************************************************************************
  type build_source.data.txt | sed -zE "s/--START_CONFIG--(.*)--END_CONFIG--.*/\1/" | sed 1d > mcp_server\config.py
  type build_source.data.txt | sed -zE "s/.*--START_TOKEN-VERIFY--(.*)--END_TOKEN-VERIFY--.*/\1/" | sed 1d > mcp_server\token_verifier.py
  echo: & echo Creating 'server.py' File:
  echo *************************************************************************
  type build_source.data.txt | sed -zE "s/.*--START_SERVER--(.*)--END_SERVER--.*/\1/" | sed 1d > mcp_server\server.py
 )
goto:eof

:_install
 if "%1"=="1" (
  echo Handle virtual environment and dependencies
  uv sync
  echo Start resouce server on port 3000, connect to authorization server ^(keycloak^)
  rem uv run mcp-simple-auth-rs --port=3000 --auth-server=http://localhost:8080 --transport=streamable-http
  uv run mcp-simple-auth-rs
  uv run mcp-simple-auth-rs
  rem echo RFC 8707 strict resource validation
  rem uv run mcp-simple-auth-rs --port=3000 --auth-server=http://localhost:8080 --transport=streamable-http --oauth-strict
  rem echo Test client with streamable HTTP
  rem set "MCP_SERVER_PORT=3000" & set "MCP_TRANSPORT_TYPE=streamable-http" & uv run mcp-simple-auth-client
 )
goto:eof

:_runBuildExercise
 if "%1"=="0" (
  if NOT "%_checkParOneBuildExercise%"=="--" (
   if "%_parOneBuildExercise%"=="--build" (
    echo Creating project, typing with skills like it is the 1980's.
    echo:
    if NOT EXIST "mcp_server" mkdir mcp_server >nul 2>nul
    call :_runBuildExercise 1 & goto:eof
   ) else if "%_parOneBuildExercise%"=="--reset" (
    echo Resetting Server:
    if EXIST "%~dp0mcp_server" rmdir /S/Q "%~dp0mcp_server" >nul 2>nul
    if EXIST "%~dp0.venv" rmdir /S/Q "%~dp0.venv" >nul 2>nul
    if EXIST "%~dp0pyproject.toml" del /Q "%~dp0pyproject.toml" >nul 2>nul
    if EXIST "%~dp0uv.lock" del /Q "%~dp0uv.lock" >nul 2>nul
    if EXIST "%~dp0..\..\exercise-mcp.code-workspace" (
     if EXIST "%~dp0..\%~n0.bat" (
      call "%~dp0..\%~n0.bat" --reset-workspace
     )
    )
    goto _closeOut
   ) else (
    set "_optOut=1"
    echo Something unexpected happened
    echo Script only accepts the options:
    goto _closeOut
   )
  ) else (
   set "_optOut=1"
   echo Something unexpected happened
   echo Script requires at least one option:
   goto _closeOut
  )
 )
 if "%1"=="1" (
  echo Making `pyproject.toml` File: & echo:
  call :_package 1
  echo Preparing `server.py` File: & echo:
  call :_main 1
  echo Credentials live in mcp_server\config.py ^(no .env file needed^).
  sed -i "s/<_KEYCLOAK_SERVER_ID_>/%_KEYCLOAK_ID%/" mcp_server\config.py
  sed -i "s/<_KEYCLOAK_SERVER_SECRET_>/%_KEYCLOAK_SECRET%/" mcp_server\config.py
  call :_runBuildExercise 2 & goto:eof
 )
 if "%1"=="2" (
  echo Building and starting the server:
  call :_install 1
  echo buildExercise Script Complete:
  goto _closeOut
 )
goto:eof

:_closeOut
 set _parOneBuildExercise=
 set _checkParOneBuildExercise=
 rem IMPORTANT - leave last
 if "%_optOut%"=="1" (
  echo   --build
  echo   --reset
 )
 set _optOut=
 rem change back to root of exercise-mcp
 cd ..\..
goto:eof
