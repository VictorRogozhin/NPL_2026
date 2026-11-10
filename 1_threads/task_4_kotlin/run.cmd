@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\kotlin\kotlinc\bin\kotlinc.bat" set "PATH=%~dp0..\..\..\..\work\kotlin\kotlinc\bin;%PATH%"
if not exist build mkdir build
call kotlinc src\Main.kt -jvm-target 11 -include-runtime -d build\correlation.jar
if errorlevel 1 exit /b 1
java -jar build\correlation.jar
