@echo off
rem buildExercise
::  Script for exercise, making a simple MCP client as hard as possible for learning purposes.

:: Global variables.
set "_parOneBuildExercise=%~1"
set "_checkParOneBuildExercise=-%_parOneBuildExercise%-"

cd /D "%~dp0"
call :_runBuildExercise 0
goto:eof

:_package
 if "%1"=="1" (
  echo ANTHROPIC_API_KEY^=%_WEATHER_CLIENT_KEY%> .env
 )
goto:eof

:_main
 if "%1"=="1" (
  if "%2"=="helper-file" (
   echo: & echo Creating Helper File:
  ) else if "%2"=="client-file" (
   echo: & echo Creating 'index.ts' File:
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
  echo Installing dependencies:
  echo:
  call npm install
  echo:
  echo Compiling client:
  echo:
  call npm run build
  echo:
  echo Running Client:
  rem The client launches the server itself, so the server has to exist first.
  if NOT EXIST "..\..\..\weather-servers\ts\weather-server\build\index.js" (
   call ..\..\..\weather-servers\ts\buildExercise.bat --build
   cd /D "%~dp0weather-client"
  )
  call node build\index.js ..\..\..\weather-servers\ts\weather-server\build\index.js
 )
goto:eof

:_runBuildExercise
 if "%1"=="0" (
  if NOT "%_checkParOneBuildExercise%"=="--" (
   if "%_parOneBuildExercise%"=="--build" (
    echo Creating client project
    echo:
    if NOT EXIST "%~dp0weather-client" mkdir "%~dp0weather-client" >nul 2>nul
    copy /Y "%~dp0README.md" "%~dp0weather-client\build_source.data.txt"
    cd /D "%~dp0weather-client"
    call :_runBuildExercise 1 & goto:eof
   ) else if "%_parOneBuildExercise%"=="--reset" (
    echo Resetting Client:
    if EXIST "%~dp0weather-client" rmdir /S/Q "%~dp0weather-client" >nul 2>nul
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
  echo Making Local MCP Client Environment: & echo:
  call :_package 1
  echo Building Local MCP Client: & echo:
  rem build using parameters
  call :_main 1 helper-file PACKAGE "package.json"
  call :_main 1 helper-file TSCONFIG "tsconfig.json"
  call :_main 1 client-file CLIENT "index.ts"
  if EXIST "%~dp0weather-client\build_source.data.txt" del /Q "%~dp0weather-client\build_source.data.txt" >nul 2>nul
  call :_runBuildExercise 2 & goto:eof
 )
 if "%1"=="2" (
  echo Running the client:
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
  rem reset the server and this client
  call "%~dp0%~n0.bat" --reset
  call develop\weather-servers\ts\buildExercise.bat --reset
 )
 set _parOneBuildExercise=
goto:eof
