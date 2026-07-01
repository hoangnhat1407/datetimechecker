@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-performance.ps1"
exit /b %ERRORLEVEL%

