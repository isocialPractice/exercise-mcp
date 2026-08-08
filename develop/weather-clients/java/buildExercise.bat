@echo off
rem buildExercise
::  Script for exercise, making a simple MCP client as hard as possible for learning purposes.

:: Global variables.
set "_parOneBuildExercise=%~1"
set "_checkParOneBuildExercise=-%_parOneBuildExercise%-"
set "_srcJava=src\main\java\org\example\weatherclient"

cd /D "%~dp0"
call :_runBuildExercise 0
goto:eof

:_package
 if "%1"=="1" (
  rem The client reads ANTHROPIC_API_KEY from the environment, so seed it for
  rem this session from the stored key instead of writing it to disk.
  set "ANTHROPIC_API_KEY=%_WEATHER_CLIENT_KEY%"
 )
goto:eof

:_main
 if "%1"=="1" (
  if "%2"=="helper-file" (
   echo: & echo Creating Helper File:
  ) else if "%2"=="client-file" (
   echo: & echo Creating 'McpClientApplication.java' File:
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
  echo Resolving dependencies and compiling:
  echo:
  call mvn clean package -DskipTests
  echo:
  echo Running Client:
  rem The client launches the server itself, so the server has to exist first.
  if NOT EXIST "..\..\..\weather-servers\java\weather-server\target\weather-server-0.0.1-SNAPSHOT.jar" (
   call ..\..\..\weather-servers\java\buildExercise.bat --build
   cd /D "%~dp0weather-client"
  )
  call java -jar target\weather-client-0.0.1-SNAPSHOT.jar
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
    if NOT EXIST "%~dp0weather-client\src\main\resources" mkdir "%~dp0weather-client\src\main\resources" >nul 2>nul
    if NOT EXIST "%~dp0weather-client\%_srcJava%" mkdir "%~dp0weather-client\%_srcJava%" >nul 2>nul
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
  call :_main 1 helper-file POM "pom.xml"
  call :_main 1 helper-file APPLICATION-YML "src\main\resources\application.yml"
  call :_main 1 helper-file SERVERS-CONFIG "src\main\resources\mcp-servers-config.json"
  call :_main 1 client-file CLIENT "%_srcJava%\McpClientApplication.java"
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
 set _srcJava=
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
  call develop\weather-servers\java\buildExercise.bat --reset
 )
 set _parOneBuildExercise=
goto:eof
