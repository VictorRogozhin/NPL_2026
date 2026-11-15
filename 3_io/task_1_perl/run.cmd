@echo off
setlocal
cd /d "%~dp0"
if exist "%ProgramFiles%\Git\usr\bin\perl.exe" set "PATH=%ProgramFiles%\Git\usr\bin;%PATH%"
if "%~1"=="" (
  perl src/deduplicate.pl data/records.csv id
) else (
  perl src/deduplicate.pl %*
)
