@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\ghc\ghc-9.6.7-x86_64-unknown-mingw32\bin\ghc.exe" set "PATH=%~dp0..\..\..\..\work\ghc\ghc-9.6.7-x86_64-unknown-mingw32\bin;%PATH%"
if not exist build mkdir build
ghc -Wall -Werror -O1 -outputdir build -o build\gray.exe src\Main.hs
if errorlevel 1 exit /b 1
build\gray.exe
