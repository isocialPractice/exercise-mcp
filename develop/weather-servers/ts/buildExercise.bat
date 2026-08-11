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
  call :_main 1 helper-file PACKAGE "package.json"
  call :_main 1 helper-file TSCONFIG "tsconfig.json"
 )
goto:eof

:_main
 if "%1"=="1" (
  if "%2"=="helper-file" (
   echo: & echo Creating Server Helper Files:
  ) else if "%2"=="server-file" (
   echo: & echo Creating 'src/index.ts' File:
  ) else (
   echo Something unexpected happened
   goto _closeOut
  )
  echo *************************************************************************
  rem Run from the project folder, where the copied data file lives.
  type build_source.data.txt | sed -zE "s/.*<!--START_%3-->\n[^\n]+\n(.*)\n```\n<!--END_%3-->.*/\1/" > %4
 )
goto:eof

:_run
 if "%1"=="1" (
  echo Installing dependencies and compiling:
  call npm install
  call npm run build
  echo:
  echo The MCP client starts the server, so launch it from here only to test:
  echo   node "%~dp0weather-server\build\index.js"
 )
goto:eof

:_runBuildExercise
 if "%1"=="0" (
  if NOT "%_checkParOneBuildExercise%"=="--" (
   if "%_parOneBuildExercise%"=="--build" (
    echo Creating server project
    echo:
    if NOT EXIST "%~dp0weather-server" mkdir "%~dp0weather-server" >nul 2>nul
    copy /Y "%~dp0README.md" "%~dp0weather-server\build_source.data.txt"
    cd /D "%~dp0weather-server"
    if NOT EXIST "%~dp0weather-server\assets"    mkdir "%~dp0weather-server\assets"    >nul 2>nul
    if NOT EXIST "%~dp0weather-server\src"       mkdir "%~dp0weather-server\src"       >nul 2>nul
    if NOT EXIST "%~dp0weather-server\src\utils" mkdir "%~dp0weather-server\src\utils" >nul 2>nul
    if NOT EXIST "%~dp0weather-server\src\gui"   mkdir "%~dp0weather-server\src\gui"   >nul 2>nul
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
  call :_main 1 helper-file UTILS-MAKE-NWS-REQUEST "src\utils\makeNwsRequest.ts"
  call :_main 1 helper-file UTILS-FORMAT-ALERT "src\utils\formatAlert.ts"
  call :_main 1 helper-file CATEGORIZE-LOCAL-WEATHER "src\utils\categorizeLocalWeather.ts"
  call :_main 1 helper-file GUI-RENDER-WEATHER "src\gui\guiRenderWeather.ts"
  call :_main 1 helper-file GUI-DRAW-WEATHER "src\gui\guiDrawWeather.ts"
  call :_main 1 helper-file GUI-WEATHER-CARD "src\gui\guiWeatherCard.ts"
  call :_main 1 server-file SERVER "src\index.ts"
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
