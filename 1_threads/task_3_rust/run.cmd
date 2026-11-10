@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0..\..\..\..\work\cargo\bin\cargo.exe" (
  set "CARGO_HOME=%~dp0..\..\..\..\work\cargo"
  set "RUSTUP_HOME=%~dp0..\..\..\..\work\rustup"
  set "PATH=%~dp0..\..\..\..\work\cargo\bin;%PATH%"
)
cargo run --release --quiet
