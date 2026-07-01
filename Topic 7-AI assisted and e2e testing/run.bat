@echo off
setlocal
chcp 65001 >nul

set "TOPIC7_DIR=%~dp0"
for %%I in ("%TOPIC7_DIR%..") do set "PROJECT_ROOT=%%~fI"

cd /d "%PROJECT_ROOT%"

if exist "%TOPIC7_DIR%.env.local" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%TOPIC7_DIR%.env.local") do (
    if not "%%A"=="" set "%%A=%%B"
  )
)

if not defined GEMINI_MODEL set "GEMINI_MODEL=gemini-3.1-flash-lite"
if not defined BASE_URL set "BASE_URL=http://localhost:18080"
if not defined AI_TEST_STEP_DELAY_MS set "AI_TEST_STEP_DELAY_MS=900"
if not defined AI_TEST_SELF_HEAL set "AI_TEST_SELF_HEAL=1"

set "PROMPTED_FOR_KEY=0"
if not defined GEMINI_API_KEY (
  set "PROMPTED_FOR_KEY=1"
  echo [CONFIG] GEMINI_API_KEY is missing.
  echo [CONFIG] Create or edit "%TOPIC7_DIR%.env.local" and add:
  echo GEMINI_API_KEY=your_api_key
  echo.
  set /p "GEMINI_API_KEY=Paste GEMINI_API_KEY for this run: "
)

if not defined GEMINI_API_KEY (
  echo [ERROR] GEMINI_API_KEY is required.
  pause
  exit /b 1
)

if "%PROMPTED_FOR_KEY%"=="1" if defined GEMINI_API_KEY call :maybe_save_key

echo [CONFIG] Model: %GEMINI_MODEL%
echo [CONFIG] Base URL: %BASE_URL%
echo [CONFIG] Step delay: %AI_TEST_STEP_DELAY_MS%ms
echo [CONFIG] Self-healing default: %AI_TEST_SELF_HEAL%
echo.

node "%TOPIC7_DIR%scripts\gemini-e2e-cli.js" assist
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" echo [DONE] AI-assisted testing exited with code %EXIT_CODE%.
pause
exit /b %EXIT_CODE%

:maybe_save_key
echo.
set /p "SAVE_KEY=Save this key to this Topic 7 .env.local for future double-click runs? (Y/N) [Default: N]: "
if /i "%SAVE_KEY%"=="Y" (
  > "%TOPIC7_DIR%.env.local" echo GEMINI_API_KEY=%GEMINI_API_KEY%
  >> "%TOPIC7_DIR%.env.local" echo GEMINI_MODEL=%GEMINI_MODEL%
  >> "%TOPIC7_DIR%.env.local" echo BASE_URL=%BASE_URL%
  >> "%TOPIC7_DIR%.env.local" echo AI_TEST_STEP_DELAY_MS=%AI_TEST_STEP_DELAY_MS%
  >> "%TOPIC7_DIR%.env.local" echo AI_TEST_SELF_HEAL=%AI_TEST_SELF_HEAL%
  echo [CONFIG] Saved local config to "%TOPIC7_DIR%.env.local"
) else (
  echo [CONFIG] Key was not saved.
)
exit /b 0
