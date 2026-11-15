@echo off
setlocal
cd /d "%~dp0"
set "local_ldc=%~dp0..\..\..\..\work\ldc\ldc2-1.43.0-windows-x64\bin"
if exist "%local_ldc%\ldc2.exe" set "PATH=%local_ldc%;%PATH%"
if not exist build mkdir build
set "vcvars=%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
if exist "%vcvars%" (
  call "%vcvars%" >nul
  if errorlevel 1 exit /b 1
  ldc2 -link-internally=false -of=build/routes.exe src/main.d
) else (
  ldc2 -of=build/routes.exe src/main.d
)
if errorlevel 1 exit /b 1
build\routes.exe %*
