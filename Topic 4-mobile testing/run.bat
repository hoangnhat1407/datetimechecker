@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-mobile-test.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
  echo Mobile testing finished successfully.
) else (
  echo Mobile testing failed with exit code %EXIT_CODE%.
)
echo.
pause
exit /b %EXIT_CODE%
