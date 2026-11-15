@echo off
setlocal
cd /d "%~dp0"
set "tools=%~dp0..\..\..\..\work"
if exist "%tools%\erlang\bin\erl.exe" set "PATH=%tools%\erlang\bin;%PATH%"
if exist "%tools%\elixir\bin\elixir.bat" set "PATH=%tools%\elixir\bin;%PATH%"
if /i "%~1"=="demo" (
  elixir src/demo.exs %2
) else (
  elixir src/server.exs %1
)
