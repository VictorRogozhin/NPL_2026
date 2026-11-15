@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\ocaml\ucrt64\bin\ocaml.exe" (
  set "PATH=%~dp0..\..\..\..\work\ocaml\ucrt64\bin;%PATH%"
  set "OCAMLLIB=%~dp0..\..\..\..\work\ocaml\ucrt64\lib\ocaml"
)
ocaml src/main.ml %*
