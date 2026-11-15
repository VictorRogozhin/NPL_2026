@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\julia\julia-1.10.10\bin\julia.exe" set "PATH=%~dp0..\..\..\..\work\julia\julia-1.10.10\bin;%PATH%"
julia --startup-file=no src/server.jl %*
