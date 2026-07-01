@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-web.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
  echo Web server stopped.
) else (
  echo Web server failed with exit code %EXIT_CODE%.
)
echo.
pause
exit /b %EXIT_CODE%
