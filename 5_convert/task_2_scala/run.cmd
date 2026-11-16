@echo off
setlocal
cd /d "%~dp0"
set "scala=%~dp0..\..\..\..\work\scala"
if not exist build mkdir build
set "default_args="
if "%~1"=="" set "default_args=data/schema.sql build/schema.dot"
if exist "%scala%\scala-compiler.jar" (
  java -cp "%scala%\*" scala.tools.nsc.Main -usejavacp -d build src/Main.scala
  if errorlevel 1 exit /b 1
  java -cp "build;%scala%\*" Main %default_args% %*
) else (
  call scalac -d build src/Main.scala
  if errorlevel 1 exit /b 1
  call scala -cp build Main %default_args% %*
)
