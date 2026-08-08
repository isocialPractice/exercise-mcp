@echo off
rem buildExercise
::  Script for exercise, making a simple MCP server as hard as possible for learning purposes.

:; Global variables.
set "_parOneBuildExercise=%~1"
set "_checkParOneBuildExercise=-%_parOneBuildExercise%-"
rem Windows restores the net9.0 package set, WSL restores net10.0.
set "_osVersion=9"

cd /D "%~dp0"
call :_runBuildExercise 0
goto:eof

:_package
 if "%1"=="1" (
  call :_main 1 PROTECTEDMCPSERVER ProtectedMcpServer.csproj
  rem The README pins one framework, so retarget it to the major this side builds.
  sed -i "s|<TargetFramework>net[0-9]*\.0</TargetFramework>|<TargetFramework>net%_osVersion%.0</TargetFramework>|" ProtectedMcpServer.csproj
 )
goto:eof

:_main
 if "%1"=="1" (
  if "%3"=="Program.cs" (
   echo: & echo Creating 'Program.cs' File:
  ) else (
   echo: & echo Creating Server Files:
  )
  echo *************************************************************************
  type build_source.data.txt | sed -zE "s/.*<!--START_%2-->\n[^\n]+\n(.*)\n```\n<!--END_%2-->.*/\1/" > %3
 )
goto:eof

:_install
 if "%1"=="1" (
  echo Run Project Server
  dotnet run --framework net%_osVersion%.0
 )
goto:eof

:_bash
 rem Hand the build to WSL from a Windows terminal. The server still listens
 rem inside the WSL VM no matter which terminal starts it, so the workspace has
 rem to address it by the VM address instead of localhost.
 where wsl >nul 2>nul
 if errorlevel 1 (
  echo WSL was not found on PATH.
  goto:eof
 )

 set "_wslIp="
 for /f "usebackq tokens=1" %%I in (`wsl -e bash -lc "hostname -I"`) do set "_wslIp=%%I"
 if not defined _wslIp (
  echo Could not read the WSL address. Is the distro running?
  goto:eof
 )
 set "_serverUrl=http://%_wslIp%:3000/"

 rem Translate this folder to its WSL path so the Linux script runs in place.
 rem The trailing backslash of %~dp0 would escape the closing quote, so it goes.
 set "_here=%~dp0"
 if "%_here:~-1%"=="\" set "_here=%_here:~0,-1%"
 set "_wslDir="
 for /f "usebackq delims=" %%I in (`wsl -e wslpath -a "%_here%"`) do set "_wslDir=%%I"
 if not defined _wslDir (
  echo Could not translate "%~dp0" to a WSL path.
  goto:eof
 )

 rem Retarget the workspace MCP client, creating the entry when it is absent.
 rem The JSON lives in the shell script because cmd cannot quote it safely.
 wsl -e bash "%_wslDir%/../buildExercise.sh" --set-workspace-server "%_serverUrl%"

 echo Starting the WSL build in a new window:
 start "MCP Server (WSL)" wsl.exe -e bash -lc "cd '%_wslDir%' && ./buildExercise.sh --build"
goto:eof

:_runBuildExercise
 if "%1"=="0" (
  if NOT "%_checkParOneBuildExercise%"=="--" (
   if "%_parOneBuildExercise%"=="--build" (
    echo Creating project, copy pasted like its 2026
    echo:
    if NOT EXIST "%~dp0Tools" mkdir Tools >nul 2>nul
    copy /Y "%~dp0README.md" "%~dp0build_source.data.txt" >nul 2>nul
    call :_runBuildExercise 1 & goto:eof
   ) else if "%_parOneBuildExercise%"=="--bash" (
    echo Building through WSL:
    echo:
    call :_bash
    goto _closeOut
   ) else if "%_parOneBuildExercise%"=="--reset" (
    echo Resetting Server:
    if EXIST "%~dp0Tools" rmdir /S/Q "%~dp0Tools" >nul 2>nul
    if EXIST "%~dp0bin" rmdir /S/Q "%~dp0bin" >nul 2>nul
    if EXIST "%~dp0obj" rmdir /S/Q "%~dp0obj" >nul 2>nul
    if EXIST "%~dp0Program.cs" del /Q "%~dp0Program.cs" >nul 2>nul
    if EXIST "%~dp0ProtectedMcpServer.csproj" del /Q "%~dp0ProtectedMcpServer.csproj" >nul 2>nul
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
  echo Making `ProtectedMcpServer.csproj` File: & echo:
  call :_package 1
  echo Preparing `server` Files: & echo:
  call :_main 1 MATH-TOOL Tools\MathTools.cs
  call :_main 1 SERVER Program.cs
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
 if EXIST "%~dp0build_source.data.txt" del /Q "%~dp0build_source.data.txt" >nul 2>nul
 set _parOneBuildExercise=
 set _checkParOneBuildExercise=
 rem IMPORTANT - leave last
 if "%_optOut%"=="1" (
  echo   --build
  echo   --bash
  echo   --reset
 )
 set _optOut=
 set _osVersion=
 set _wslIp=
 set _serverUrl=
 set _wslDir=
 set _here=
 rem change back to root of exercise-mcp
 cd ..\..
goto:eof
