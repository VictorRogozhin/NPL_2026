@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\erlang\bin\erl.exe" set "PATH=%~dp0..\..\..\..\work\erlang\bin;%PATH%"
where erlc >nul 2>nul
if errorlevel 1 (
  echo Erlang/OTP not found. Add its bin directory to PATH.
  exit /b 1
)
if not exist build mkdir build
erlc -Werror -o build src\parallel_sum.erl
if errorlevel 1 exit /b 1
erl -noshell -pa build -s parallel_sum main -s init stop
