@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-mobile-test.ps1" -ManualDemo
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
  echo Native mobile manual demo is ready.
  echo Open DateTimeChecker on the emulator and enter values manually.
) else (
  echo Native mobile setup failed with exit code %EXIT_CODE%.
)
echo.
pause
exit /b %EXIT_CODE%
