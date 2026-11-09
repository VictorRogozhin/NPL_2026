@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\gnat\gnat-x86_64-windows64-15.2.0-1\bin\gnatmake.exe" set "PATH=%~dp0..\..\..\..\work\gnat\gnat-x86_64-windows64-15.2.0-1\bin;%PATH%"
if not exist build mkdir build
if not exist results mkdir results
gnatmake -q -gnat2022 -gnatwa -gnata -D build -o build/main.exe src/main.adb
if errorlevel 1 exit /b 1
build\main.exe results\index.txt data\c.txt data\b.txt data\a.txt
if errorlevel 1 exit /b 1
type results\index.txt
