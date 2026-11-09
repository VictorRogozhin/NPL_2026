@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\erlang\bin\erl.exe" set "PATH=%~dp0..\..\..\..\work\erlang\bin;%PATH%"
if not exist build mkdir build
erlc -Werror -o build src\components.erl
if errorlevel 1 exit /b 1
erl -noshell -pa build -s components main -s init stop
