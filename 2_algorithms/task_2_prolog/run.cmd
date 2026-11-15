@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\swipl\bin\swipl.exe" set "PATH=%~dp0..\..\..\..\work\swipl\bin;%PATH%"
swipl -q -s src\main.pl -- %*
