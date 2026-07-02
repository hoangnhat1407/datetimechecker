@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "TARGET_BRANCH=hoangnhat-draft"
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_DIR=%%~fI"
set "NOTE_FILE=Topic 3-CICD\DEMO_CI_NOTE.md"
set "ACTIONS_URL=https://github.com/nhatnhm1405/datetimechecker/actions"
set "REMOTE_NAME=cicd-demo"

pushd "%PROJECT_DIR%"

echo ============================================================
echo DateTimeChecker - CI/CD demo trigger
echo ============================================================
echo.

where git >nul 2>&1
if errorlevel 1 (
    echo ERROR: Git was not found in PATH.
    echo Install Git or open this project from Git Bash/PowerShell with Git available.
    echo.
    pause
    popd
    exit /b 1
)

for /f "delims=" %%B in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%B"

if "%CURRENT_BRANCH%"=="" (
    echo ERROR: Could not detect the current Git branch.
    echo.
    pause
    popd
    exit /b 1
)

if /I not "%CURRENT_BRANCH%"=="%TARGET_BRANCH%" (
    echo ERROR: You are currently on branch "%CURRENT_BRANCH%".
    echo This demo runner only pushes from "%TARGET_BRANCH%" to avoid touching main.
    echo.
    echo Run this first, then double-click run.bat again:
    echo   git switch %TARGET_BRANCH%
    echo.
    pause
    popd
    exit /b 1
)

git remote get-url "%REMOTE_NAME%" >nul 2>&1
if errorlevel 1 (
    set "REMOTE_NAME=origin"
)

for /f "delims=" %%R in ('git remote get-url "%REMOTE_NAME%" 2^>nul') do set "REMOTE_URL=%%R"

if "%REMOTE_URL%"=="" (
    echo ERROR: Could not read Git remote "%REMOTE_NAME%".
    echo.
    pause
    popd
    exit /b 1
)

echo Current branch : %CURRENT_BRANCH%
echo Target remote  : %REMOTE_NAME%
echo Remote URL     : %REMOTE_URL%
echo Target push    : %REMOTE_NAME%/%CURRENT_BRANCH%
echo.
echo [preflight] Checking whether this Git account can push to the target branch...
git push --dry-run -u "%REMOTE_NAME%" "%CURRENT_BRANCH%"
if errorlevel 1 (
    echo.
    echo ERROR: Push permission check failed.
    echo The current Git/GitHub credential cannot push to:
    echo   %REMOTE_URL%
    echo.
    echo Fix GitHub login/token/permission first, then run this file again.
    echo No new CI demo commit was created by this run.
    echo.
    pause
    popd
    exit /b 1
)

for /f "delims=" %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "RUN_ID=%%T"

if "%RUN_ID%"=="" (
    echo ERROR: Could not generate run timestamp.
    echo.
    pause
    popd
    exit /b 1
)

echo [1/4] Updating demo note...
(
    echo # CI Demo Note
    echo.
    echo This file is updated by `Topic 3-CICD\run.bat` to create a fresh commit and trigger GitHub Actions.
    echo.
    echo Last demo run: %RUN_ID%
    echo Branch: %CURRENT_BRANCH%
    echo Machine: %COMPUTERNAME%
) > "%NOTE_FILE%"

echo [2/4] Staging changes...
git add -A
if errorlevel 1 (
    echo ERROR: git add failed.
    echo.
    pause
    popd
    exit /b 1
)

echo [3/4] Creating commit...
git commit -m "ci: trigger demo run %RUN_ID%"
if errorlevel 1 (
    echo ERROR: git commit failed.
    echo Check Git user.name/user.email or resolve any repository issue, then run again.
    echo.
    pause
    popd
    exit /b 1
)

echo [4/4] Pushing to GitHub...
git push -u "%REMOTE_NAME%" "%CURRENT_BRANCH%"
if errorlevel 1 (
    echo ERROR: git push failed.
    echo Check GitHub login/token/network access, then run again.
    echo.
    pause
    popd
    exit /b 1
)

echo.
echo ============================================================
echo SUCCESS: Code pushed to GitHub.
echo GitHub Actions should start automatically because workflow runs on push.
echo Open Actions:
echo %ACTIONS_URL%
echo ============================================================
echo.
pause

popd
exit /b 0
