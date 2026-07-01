@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-visual-regression.ps1" %*
exit /b %ERRORLEVEL%
