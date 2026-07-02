@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "TARGET_BRANCH=hoangnhat-draft"
set "REMOTE_NAME=cicd-demo"
set "REPO_NAME=datetimechecker-cicd-demo"

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_DIR=%%~fI"

pushd "%PROJECT_DIR%"

echo ============================================================
echo DateTimeChecker - Create new GitHub repo and push CI/CD demo
echo ============================================================
echo.

where git >nul 2>&1
if errorlevel 1 (
    echo ERROR: Git was not found in PATH.
    echo.
    pause
    popd
    exit /b 1
)

where gh >nul 2>&1
if errorlevel 1 (
    echo ERROR: GitHub CLI ^(gh^) was not found.
    echo.
    echo Install GitHub CLI from https://cli.github.com/, then login:
    echo   gh auth login
    echo.
    echo After that, run this file again.
    echo.
    pause
    popd
    exit /b 1
)

gh auth status >nul 2>&1
if errorlevel 1 (
    echo ERROR: GitHub CLI is installed but not logged in.
    echo.
    echo Run this first:
    echo   gh auth login
    echo.
    pause
    popd
    exit /b 1
)

for /f "delims=" %%B in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%B"

if /I not "%CURRENT_BRANCH%"=="%TARGET_BRANCH%" (
    echo ERROR: You are currently on branch "%CURRENT_BRANCH%".
    echo This script only pushes from "%TARGET_BRANCH%".
    echo.
    echo Run this first:
    echo   git switch %TARGET_BRANCH%
    echo.
    pause
    popd
    exit /b 1
)

for /f "delims=" %%U in ('gh api user --jq ".login" 2^>nul') do set "GH_USER=%%U"

if "%GH_USER%"=="" (
    echo ERROR: Could not read the logged-in GitHub username from gh.
    echo.
    pause
    popd
    exit /b 1
)

echo GitHub user : %GH_USER%
echo Repo name   : %REPO_NAME%
echo Branch      : %CURRENT_BRANCH%
echo Remote name : %REMOTE_NAME%
echo.

echo [1/4] Staging current project changes...
git add -A
if errorlevel 1 (
    echo ERROR: git add failed.
    echo.
    pause
    popd
    exit /b 1
)

git diff --cached --quiet
if errorlevel 1 (
    echo [2/4] Creating local commit for the new repo...
    git commit -m "chore: prepare CI/CD demo repository"
    if errorlevel 1 (
        echo ERROR: git commit failed.
        echo.
        pause
        popd
        exit /b 1
    )
) else (
    echo [2/4] No staged changes to commit.
)

git remote get-url "%REMOTE_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo [3/4] Remote "%REMOTE_NAME%" already exists. Reusing it.
    git push -u "%REMOTE_NAME%" "%CURRENT_BRANCH%"
    if errorlevel 1 (
        echo ERROR: Push to existing "%REMOTE_NAME%" remote failed.
        echo.
        pause
        popd
        exit /b 1
    )
) else (
    echo [3/4] Creating GitHub repo "%GH_USER%/%REPO_NAME%" and pushing...
    gh repo create "%REPO_NAME%" --public --source "." --remote "%REMOTE_NAME%" --push
    if errorlevel 1 (
        echo ERROR: GitHub repo creation or push failed.
        echo.
        echo If the repo name already exists, edit REPO_NAME in this file and run again.
        echo.
        pause
        popd
        exit /b 1
    )
)

echo [4/4] Done.
echo.
echo New repo:
echo https://github.com/%GH_USER%/%REPO_NAME%
echo.
echo GitHub Actions:
echo https://github.com/%GH_USER%/%REPO_NAME%/actions
echo.
echo Future Topic 3-CICD\run.bat runs will prefer the "%REMOTE_NAME%" remote.
echo.
pause

popd
exit /b 0
