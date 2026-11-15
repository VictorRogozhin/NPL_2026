@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\zig\zig-x86_64-windows-0.14.1\zig.exe" set "PATH=%~dp0..\..\..\..\work\zig\zig-x86_64-windows-0.14.1;%PATH%"
if not exist build mkdir build
zig build-exe src/main.zig -O ReleaseSafe --cache-dir build/cache --global-cache-dir build/global-cache -femit-bin=build/line-index.exe
if errorlevel 1 exit /b 1
if not "%~1"=="" (
  build\line-index.exe %*
  exit /b
)
build\line-index.exe data/lines.txt build/index-%RANDOM%-%RANDOM%.bin
