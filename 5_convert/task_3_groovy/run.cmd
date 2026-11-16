@echo off
setlocal
cd /d "%~dp0"
if not exist build mkdir build
set "default_args="
if "%~1"=="" set "default_args=data/directory.ldif build/directory.csv"
set "groovy_jar=%~dp0..\..\..\..\work\groovy\groovy.jar"
if exist "%groovy_jar%" (
  java -cp "%groovy_jar%" groovy.ui.GroovyMain src/Main.groovy %default_args% %*
) else (
  call groovy src/Main.groovy %default_args% %*
)
