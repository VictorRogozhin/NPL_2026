$ErrorActionPreference = 'Stop'
$compiler = Join-Path $PSScriptRoot '../../../../work/gnat/gnat-x86_64-windows64-15.2.0-1/bin'
if (Test-Path $compiler) { $env:PATH = "$compiler;$env:PATH" }
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force build | Out-Null
    & gnatmake -gnat2022 -gnatwa -gnata -D build -o build/main.exe src/main.adb
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
    & ./build/main.exe
    if ($LASTEXITCODE -ne 0) { throw 'Execution failed' }
} finally { Pop-Location }
