@echo off
setlocal
cd /d "%~dp0"
set "tools=%~dp0..\..\..\..\work"
if exist "%tools%\nim\nim-2.2.15\bin\nim.exe" set "PATH=%tools%\nim\nim-2.2.15\bin;%PATH%"
if exist "%tools%\gnat\gnat-x86_64-windows64-15.2.0-1\bin\gcc.exe" set "PATH=%tools%\gnat\gnat-x86_64-windows64-15.2.0-1\bin;%PATH%"
if not exist build mkdir build
nim c --threads:off --gcc.options.linker:-Wl,--as-needed --warning:Deprecated:off --hints:off --nimcache:build/cache -o:build/patch.exe src/main.nim
if errorlevel 1 exit /b 1
if not "%~1"=="" (
  build\patch.exe %*
  exit /b
)
build\patch.exe create data/old.bin data/new.bin build/patch.bin
if errorlevel 1 exit /b 1
build\patch.exe apply data/old.bin build/patch.bin build/restored.bin
if errorlevel 1 exit /b 1
fc /b data\new.bin build\restored.bin
