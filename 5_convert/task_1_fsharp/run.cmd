@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\dotnet\dotnet.exe" set "PATH=%~dp0..\..\..\..\work\dotnet;%PATH%"
set "DOTNET_CLI_HOME=%~dp0build"
set "DOTNET_NOLOGO=1"
set "DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=false"
set "DOTNET_CLI_TELEMETRY_OPTOUT=1"
if not exist build mkdir build
if "%~1"=="" (
  dotnet fsi --exec src/main.fsx data/points.geojson build/points.csv
) else (
  dotnet fsi --exec src/main.fsx %*
)
