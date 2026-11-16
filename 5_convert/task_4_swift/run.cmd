@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0.local-env.cmd" (
    call "%~dp0.local-env.cmd"
    if errorlevel 1 exit /b 1
)
where swiftc >nul 2>nul
if errorlevel 1 (
    echo Error: Swift compiler not found. Install Swift and add swiftc to PATH. >&2
    exit /b 1
)
if not exist build mkdir build
if defined SDKROOT (swiftc -sdk "%SDKROOT%" -module-cache-path build/cache src/main.swift -o build/converter.exe >nul) else (swiftc -module-cache-path build/cache src/main.swift -o build/converter.exe >nul)
if errorlevel 1 exit /b 1
if "%~1"=="" (
    build\converter.exe data/sample.ppm build/sample.bmp
) else (
    build\converter.exe %*
)
