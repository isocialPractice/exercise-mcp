@echo off
rem buildExercise
::  Script for exercise, making a simple MCP server as hard as possible for learning purposes.

:: Global variables.
set "_parOneBuildExercise=%~1"
set "_checkParOneBuildExercise=-%_parOneBuildExercise%-"

cd /D "%~dp0"
call :_runBuildExercise 0
goto:eof

:_package
 if "%1"=="1" (
  echo [project]> pyproject.toml
  echo name ^= "weather-server">> pyproject.toml
  echo version ^= "0.1.0">> pyproject.toml
  echo description ^= "A simple MCP weather server that renders a GUI from local conditions">> pyproject.toml
  echo requires-python ^= ">=3.10">> pyproject.toml
  echo dependencies ^= [>> pyproject.toml
  echo   "httpx2>=2.9",>> pyproject.toml
  echo   "mcp>=2.0.0rc1",>> pyproject.toml
  echo ]>> pyproject.toml
  echo:>> pyproject.toml
  rem Server runs as a script, so nothing is built or installed as a package.
  echo [tool.uv]>> pyproject.toml
  echo package ^= false>> pyproject.toml
 )
goto:eof

:_main
 if "%1"=="1" (
  if "%2"=="helper-file" (
   echo: & echo Creating Server Helper Files:
  ) else if "%2"=="server-file" (
   echo: & echo Creating 'server.py' File:
  ) else (
   echo Something unexpected happened
   goto _closeOut
  )
  echo *************************************************************************
  type build_source.data.txt | sed -zE "s/.*--START_%3--(.*)--END_%3--.*/\1/" | sed 1d > %4
 )
goto:eof

:_run
 if "%1"=="1" (
  echo Creating virtual environment and installing dependencies:
  uv sync
  echo:
  echo The MCP client starts the server, so launch it from here only to test:
  echo   uv --directory "%~dp0weather-server" run server.py
 )
goto:eof

:_runBuildExercise
 if "%1"=="0" (
  if NOT "%_checkParOneBuildExercise%"=="--" (
   if "%_parOneBuildExercise%"=="--build" (
    echo Creating server project
    echo:
    if NOT EXIST "%~dp0weather-server" mkdir "%~dp0weather-server" >nul 2>nul
    copy /Y "%~dp0build_source.data.txt" "%~dp0weather-server\build_source.data.txt"
    cd /D "%~dp0weather-server"
    if NOT EXIST "%~dp0weather-server\assets" mkdir "%~dp0weather-server\assets" >nul 2>nul
    if NOT EXIST "%~dp0weather-server\gui"    mkdir "%~dp0weather-server\gui"    >nul 2>nul
    if NOT EXIST "%~dp0weather-server\utils"  mkdir "%~dp0weather-server\utils"  >nul 2>nul
    copy /Y "%~dp0..\assets\*" "%~dp0weather-server\assets\"
    call :_runBuildExercise 1 & goto:eof
   ) else if "%_parOneBuildExercise%"=="--reset" (
    echo Resetting Server:
    if EXIST "%~dp0weather-server" rmdir /S/Q "%~dp0weather-server" >nul 2>nul
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
  echo Making Local MCP Server Environment: & echo:
  call :_package 1
  echo Building Local MCP Server: & echo:
  rem build using parameters
  call :_main 1 helper-file UTILS-MAKE-NWS-REQUEST "utils\make_nws_request.py"
  call :_main 1 helper-file UTILS-FORMAT-ALERT "utils\format_alert.py"
  call :_main 1 helper-file CATEGORIZE-LOCAL-WEATHER "utils\categorize_local_weather.py"
  call :_main 1 helper-file GUI-RENDER-WEATHER "gui\gui_render_weather.py"
  call :_main 1 helper-file GUI-DRAW-WEATHER "gui\gui_draw_weather.py"
  call :_main 1 server-file SERVER "server.py"
  if EXIST "%~dp0weather-server\build_source.data.txt" del /Q "%~dp0weather-server\build_source.data.txt" >nul 2>nul
  call :_runBuildExercise 2 & goto:eof
 )
 if "%1"=="2" (
  echo Running the server:
  call :_run 1
  echo buildExercise Script Complete:
  goto _closeOut
 )
goto:eof

:_closeOut
 set _checkParOneBuildExercise=
 rem IMPORTANT - leave last
 if "%_optOut%"=="1" (
  echo   --build
  echo   --reset
 )
 set _optOut=
 rem change back to root of exercise-mcp
 rem IMPORTANT - leave last
 cd ..\..\..
 if "%_parOneBuildExercise%"=="--build" (
  cd ..
 )
 set _parOneBuildExercise=
goto:eof
