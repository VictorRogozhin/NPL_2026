@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\lua\lua.exe" set "PATH=%~dp0..\..\..\..\work\lua;%PATH%"
if "%~1"=="" (
  lua src/main.lua data/before.tsv data/after.tsv
) else (
  lua src/main.lua %*
)
