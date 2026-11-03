@echo off
if "%~1"=="" (
  echo Usage: run.cmd C:\path\to\budo.exe
  exit /b 1
)
powershell.exe -NoProfile -File "%~dp0run.ps1" -BudoPath "%~1"
if errorlevel 1 pause
