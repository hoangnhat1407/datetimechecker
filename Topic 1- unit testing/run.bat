@echo off
setlocal EnableExtensions
chcp 65001 >nul

pushd "%~dp0"

if defined MAVEN_OPTS (
    set "MAVEN_OPTS=-XX:+EnableDynamicAgentLoading -Xshare:off %MAVEN_OPTS%"
) else (
    set "MAVEN_OPTS=-XX:+EnableDynamicAgentLoading -Xshare:off"
)

set "REPORT_ROOT=%CD%\reports"
if not exist "%REPORT_ROOT%" mkdir "%REPORT_ROOT%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "RUN_ID=%%I"
set "REPORT_DIR=%REPORT_ROOT%\run-%RUN_ID%"
mkdir "%REPORT_DIR%" >nul 2>&1

echo ============================================================
echo DATE TIME CHECKER - TOPIC 1 UNIT TEST RUNNER
echo ============================================================
echo Working folder : %CD%
echo Test source    : %CD%\src\test\java
echo Test data      : %CD%\test-data.json
echo Report folder  : %REPORT_DIR%
echo.

if not exist "..\mvnw.cmd" (
    echo ERROR: Cannot find Maven wrapper at ..\mvnw.cmd
    echo Please keep Topic 1 inside the project root folder.
    echo.
    pause
    popd
    exit /b 1
)

if not exist "pom.xml" (
    echo ERROR: Cannot find Topic 1\pom.xml
    echo.
    pause
    popd
    exit /b 1
)

if not exist "test-data.json" (
    echo ERROR: Cannot find Topic 1\test-data.json
    echo.
    pause
    popd
    exit /b 1
)

if exist "target\surefire-reports" rmdir /s /q "target\surefire-reports"

echo [1/2] Running unit tests with Maven...
echo ------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command "$cmd='call ..\mvnw.cmd -f pom.xml clean test -Dsurefire.useFile=false -DtrimStackTrace=false 2^>^&1'; & $env:ComSpec /d /c $cmd | Tee-Object -FilePath '%REPORT_DIR%\run.log'; exit $LASTEXITCODE"
set "TEST_EXIT=%ERRORLEVEL%"

echo.
echo [2/2] Building detailed Surefire report...
echo ------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command "$files=Get-ChildItem -Path 'target\surefire-reports\TEST-*.xml' -ErrorAction SilentlyContinue; if(-not $files){ Write-Host 'No Surefire XML report files were found.'; exit 1 }; $rows=foreach($file in $files){ [xml]$xml=Get-Content -LiteralPath $file.FullName; $suite=$xml.testsuite; [pscustomobject]@{ TestClass=$suite.name; Tests=[int]$suite.tests; Passed=([int]$suite.tests-[int]$suite.failures-[int]$suite.errors-[int]$suite.skipped); Failed=[int]$suite.failures; Errors=[int]$suite.errors; Skipped=[int]$suite.skipped; TimeSec=[double]$suite.time } }; $rows=$rows | Sort-Object TestClass; $summaryPath='%REPORT_DIR%\summary.txt'; 'DETAILED UNIT TEST REPORT' | Tee-Object -FilePath $summaryPath; 'Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tee-Object -FilePath $summaryPath -Append; '' | Tee-Object -FilePath $summaryPath -Append; $rows | Format-Table -AutoSize | Tee-Object -FilePath $summaryPath -Append; $tests=($rows | Measure-Object Tests -Sum).Sum; $passed=($rows | Measure-Object Passed -Sum).Sum; $failed=($rows | Measure-Object Failed -Sum).Sum; $errors=($rows | Measure-Object Errors -Sum).Sum; $skipped=($rows | Measure-Object Skipped -Sum).Sum; $time=($rows | Measure-Object TimeSec -Sum).Sum; '' | Tee-Object -FilePath $summaryPath -Append; ('TOTAL TESTS : ' + $tests) | Tee-Object -FilePath $summaryPath -Append; ('PASSED      : ' + $passed) | Tee-Object -FilePath $summaryPath -Append; ('FAILED      : ' + $failed) | Tee-Object -FilePath $summaryPath -Append; ('ERRORS      : ' + $errors) | Tee-Object -FilePath $summaryPath -Append; ('SKIPPED     : ' + $skipped) | Tee-Object -FilePath $summaryPath -Append; ('TIME        : {0:N3} seconds' -f $time) | Tee-Object -FilePath $summaryPath -Append; if(($failed + $errors) -eq 0){ 'RESULT      : PASS' | Tee-Object -FilePath $summaryPath -Append } else { 'RESULT      : FAIL' | Tee-Object -FilePath $summaryPath -Append }"

echo.
echo ============================================================
if "%TEST_EXIT%"=="0" (
    echo FINAL RESULT: PASS - all unit tests passed.
) else (
    echo FINAL RESULT: FAIL - at least one unit test failed.
)
echo Maven log      : %REPORT_DIR%\run.log
echo Summary report : %REPORT_DIR%\summary.txt
echo ============================================================
echo.
pause

popd
exit /b %TEST_EXIT%
