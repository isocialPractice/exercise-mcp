@echo off
rem buildExercise
::  Script for exercise, making a simple MCP server as hard as possible for learning purposes.

:: Global variables.
set "_parOneBuildExercise=%~1"
set "_checkParOneBuildExercise=-%_parOneBuildExercise%-"
set "_srcJava=src\main\java\org\example\weatherserver"
set "_mvnVersion=3.9.11"

cd /D "%~dp0"
call :_runBuildExercise 0
goto:eof

:_package
 if "%1"=="1" (
  call :_main 1 helper-file POM "pom.xml"
  call :_main 1 helper-file APPLICATION-PROPERTIES "src\main\resources\application.properties"
 )
goto:eof

:_main
 if "%1"=="1" (
  if "%2"=="helper-file" (
   echo: & echo Creating Server Helper Files:
  ) else if "%2"=="server-file" (
   echo: & echo Creating 'McpServerApplication.java' File:
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
 rem Written line by line rather than as one block, so %_mvnCmd% expands after
 rem :_resolveMaven sets it.
 if NOT "%1"=="1" goto:eof
 echo Resolving dependencies and compiling:
 call :_resolveJavaHome
 call :_resolveMaven
 call "%_mvnCmd%" clean package -DskipTests
 echo:
 echo The MCP client starts the server, so launch it from here only to test:
 echo   java -Dspring.ai.mcp.server.transport=STDIO -jar "%~dp0weather-server\target\weather-server-0.0.1-SNAPSHOT.jar"
goto:eof

:_resolveJavaHome
 rem mvn.cmd refuses to start without JAVA_HOME, so derive it from java on PATH.
 if defined JAVA_HOME goto:eof
 set "_javaExe="
 for /f "delims=" %%J in ('where java 2^>nul') do if not defined _javaExe set "_javaExe=%%J"
 if not defined _javaExe goto:eof
 set "JAVA_HOME=%_javaExe:\bin\java.exe=%"
goto:eof

:_resolveMaven
 rem Use Maven from PATH when present, else a copy bootstrapped into .maven\
 rem so the exercise builds on a machine with only a JDK.
 set "_mvnCmd=mvn"
 where mvn >nul 2>nul
 if NOT errorlevel 1 goto:eof
 set "_mvnHome=%~dp0.maven\apache-maven-%_mvnVersion%"
 if EXIST "%_mvnHome%\bin\mvn.cmd" set "_mvnCmd=%_mvnHome%\bin\mvn.cmd"
 if EXIST "%_mvnHome%\bin\mvn.cmd" goto:eof
 echo Maven is not on PATH, so a local copy bootstraps into .maven\
 if NOT EXIST "%~dp0.maven" mkdir "%~dp0.maven" >nul 2>nul
 curl.exe -fL -o "%~dp0.maven\maven.zip" "https://archive.apache.org/dist/maven/maven-3/%_mvnVersion%/binaries/apache-maven-%_mvnVersion%-bin.zip"
 tar -xf "%~dp0.maven\maven.zip" -C "%~dp0.maven"
 del /Q "%~dp0.maven\maven.zip" >nul 2>nul
 if EXIST "%_mvnHome%\bin\mvn.cmd" set "_mvnCmd=%_mvnHome%\bin\mvn.cmd"
 if EXIST "%_mvnHome%\bin\mvn.cmd" goto:eof
 echo Could not bootstrap Maven. Install it and run this script again:
 echo   winget install Apache.Maven
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
    if NOT EXIST "%~dp0weather-server\src\main\resources" mkdir "%~dp0weather-server\src\main\resources" >nul 2>nul
    if NOT EXIST "%~dp0weather-server\%_srcJava%\utils" mkdir "%~dp0weather-server\%_srcJava%\utils" >nul 2>nul
    if NOT EXIST "%~dp0weather-server\%_srcJava%\gui"   mkdir "%~dp0weather-server\%_srcJava%\gui"   >nul 2>nul
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
  call :_main 1 helper-file WEATHER-SERVICE "%_srcJava%\WeatherService.java"
  call :_main 1 helper-file UTILS-MAKE-NWS-REQUEST "%_srcJava%\utils\NwsClient.java"
  call :_main 1 helper-file UTILS-FORMAT-ALERT "%_srcJava%\utils\FormatAlert.java"
  call :_main 1 helper-file CATEGORIZE-LOCAL-WEATHER "%_srcJava%\utils\CategorizeLocalWeather.java"
  call :_main 1 helper-file GUI-RENDER-WEATHER "%_srcJava%\gui\GuiRenderWeather.java"
  call :_main 1 helper-file GUI-DRAW-WEATHER "%_srcJava%\gui\GuiDrawWeather.java"
  call :_main 1 server-file SERVER "%_srcJava%\McpServerApplication.java"
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
 set _srcJava=
 set _mvnVersion=
 set _mvnCmd=
 set _mvnHome=
 set _javaExe=
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
