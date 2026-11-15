@echo off
setlocal
cd /d "%~dp0"
set "clj_runtime=%~dp0..\..\..\..\work\clojure"
if not exist "%clj_runtime%\clojure.jar" (
  clojure -M src/main.clj %*
  exit /b
)
java -cp "%clj_runtime%\*" clojure.main src/main.clj %*
