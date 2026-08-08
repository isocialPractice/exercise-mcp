@echo off
rem buildExercise
::  Script for exercise, making a simple MCP server as hard as possible for learning purposes.

:: Global variables.
set "_parOneBuildExercise=%~1"
set "_checkParOneBuildExercise=-%_parOneBuildExercise%-"
set "_gradleVersion=8.14"

cd /D "%~dp0"
call :_runBuildExercise 0
goto:eof

:_package
 if "%1"=="1" (
  call :_main 1 helper-file SETTINGS-GRADLE "settings.gradle.kts"
  call :_main 1 helper-file BUILD-GRADLE "build.gradle.kts"
 )
goto:eof

:_main
 if "%1"=="1" (
  if "%2"=="helper-file" (
   echo: & echo Creating Server Helper Files:
  ) else if "%2"=="server-file" (
   echo: & echo Creating 'Main.kt' File:
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
 rem Written line by line rather than as one block, so %_gradleCmd% expands
 rem after :_resolveGradle sets it.
 if NOT "%1"=="1" goto:eof
 echo Resolving dependencies and compiling:
 call :_resolveGradle
 call "%_gradleCmd%" build
 echo:
 echo The MCP client starts the server, so launch it from here only to test:
 echo   java -jar "%~dp0weather-server\build\libs\weather-server-0.1.0-all.jar"
goto:eof

:_resolveGradle
 rem Use Gradle from PATH when present, else a copy bootstrapped into
 rem .gradle-dist\ so the exercise builds on a machine with only a JDK.
 set "_gradleCmd=gradle"
 where gradle >nul 2>nul
 if NOT errorlevel 1 goto:eof
 set "_gradleHome=%~dp0.gradle-dist\gradle-%_gradleVersion%"
 if EXIST "%_gradleHome%\bin\gradle.bat" set "_gradleCmd=%_gradleHome%\bin\gradle.bat"
 if EXIST "%_gradleHome%\bin\gradle.bat" goto:eof
 echo Gradle is not on PATH, so a local copy bootstraps into .gradle-dist\
 if NOT EXIST "%~dp0.gradle-dist" mkdir "%~dp0.gradle-dist" >nul 2>nul
 curl.exe -fL -o "%~dp0.gradle-dist\gradle.zip" "https://services.gradle.org/distributions/gradle-%_gradleVersion%-bin.zip"
 tar -xf "%~dp0.gradle-dist\gradle.zip" -C "%~dp0.gradle-dist"
 del /Q "%~dp0.gradle-dist\gradle.zip" >nul 2>nul
 if EXIST "%_gradleHome%\bin\gradle.bat" set "_gradleCmd=%_gradleHome%\bin\gradle.bat"
 if EXIST "%_gradleHome%\bin\gradle.bat" goto:eof
 echo Could not bootstrap Gradle. Install it and run this script again:
 echo   winget install Gradle.Gradle
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
    if NOT EXIST "%~dp0weather-server\assets" mkdir "%~dp0weather-server\assets" >nul 2>nul
    if NOT EXIST "%~dp0weather-server\src\main\kotlin" mkdir "%~dp0weather-server\src\main\kotlin" >nul 2>nul
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
  call :_main 1 helper-file WEATHER-API "src\main\kotlin\WeatherApi.kt"
  call :_main 1 helper-file CATEGORIZE-LOCAL-WEATHER "src\main\kotlin\CategorizeLocalWeather.kt"
  call :_main 1 helper-file GUI-RENDER-WEATHER "src\main\kotlin\GuiRenderWeather.kt"
  call :_main 1 helper-file GUI-DRAW-WEATHER "src\main\kotlin\GuiDrawWeather.kt"
  call :_main 1 server-file SERVER "src\main\kotlin\Main.kt"
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
 set _gradleVersion=
 set _gradleCmd=
 set _gradleHome=
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
