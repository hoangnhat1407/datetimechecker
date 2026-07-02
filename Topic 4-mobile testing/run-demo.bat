@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-mobile-test.ps1" -Demo
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
  echo Mobile phone demo finished successfully.
) else (
  echo Mobile phone demo failed with exit code %EXIT_CODE%.
)
echo.
pause
exit /b %EXIT_CODE%
