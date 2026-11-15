@echo off
setlocal
cd /d "%~dp0"
for /d %%D in ("%~dp0..\..\..\..\work\ruby\rubyinstaller-*") do if exist "%%~fD\bin\ruby.exe" set "PATH=%%~fD\bin;%PATH%"
ruby src/server.rb %*
