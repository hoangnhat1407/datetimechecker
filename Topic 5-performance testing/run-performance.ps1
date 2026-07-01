$ErrorActionPreference = 'Stop'

$TopicDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Resolve-Path (Join-Path $TopicDir '..')
$AppPort = 18081
$BaseUrl = "http://localhost:$AppPort"
$DemoMode = 'quick'
$RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportDir = Join-Path $TopicDir "reports\run-$RunId"
$LogFile = Join-Path $ReportDir 'run.log'
$K6ConsoleLog = Join-Path $ReportDir 'k6-console.log'
$K6SummaryFile = Join-Path $ReportDir 'k6-summary.json'
$AppLogFile = Join-Path $ReportDir 'spring-boot.log'

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

function Write-Log {
    param([string]$Message = '')
    $Message | Tee-Object -FilePath $LogFile -Append
}

function Test-DateTimeCheckerApi {
    try {
        $body = @{ day = '1'; month = '1'; year = '2000' } | ConvertTo-Json -Compress
        $response = Invoke-RestMethod `
            -Uri "$BaseUrl/api/datetime/check" `
            -Method Post `
            -ContentType 'application/json' `
            -Body $body `
            -TimeoutSec 2

        return $null -ne $response.valid
    } catch {
        return $false
    }
}

function Test-PortInUse {
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $async = $client.BeginConnect('127.0.0.1', $AppPort, $null, $null)
        if ($async.AsyncWaitHandle.WaitOne(1000)) {
            $client.EndConnect($async)
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Stop-WithPause {
    param(
        [int]$ExitCode,
        [string]$Message
    )

    if ($Message) {
        Write-Log $Message
    }
    Write-Log ''
    Write-Log "[INFO] Report folder: $ReportDir"
    Read-Host 'Press Enter to close'
    exit $ExitCode
}

Write-Log '============================================================'
Write-Log 'Topic 5 - Performance Testing Demo with k6'
Write-Log 'Project: DateTimeChecker'
Write-Log "Run ID: run-$RunId"
Write-Log "Report folder: $ReportDir"
Write-Log "Target API: $BaseUrl/api/datetime/check"
Write-Log "Demo mode: $DemoMode"
Write-Log '============================================================'
Write-Log ''

$k6Path = (Get-Command k6 -ErrorAction SilentlyContinue)
if (-not $k6Path) {
    Stop-WithPause 1 '[ERROR] k6 is not installed or not available in PATH.'
}

$javaPath = (Get-Command java -ErrorAction SilentlyContinue)
if (-not $javaPath) {
    Stop-WithPause 1 '[ERROR] Java is not installed or not available in PATH.'
}

Write-Log '[INFO] Environment information'
Write-Log "[INFO] k6 path: $($k6Path.Source)"
Write-Log "[INFO] Java path: $($javaPath.Source)"
Write-Log '[INFO] Java version:'
cmd /c "java -version 2>&1" | Tee-Object -FilePath $LogFile -Append
Write-Log ''

if (Test-DateTimeCheckerApi) {
    Write-Log '[INFO] Spring Boot app is already running and DateTimeChecker API is reachable.'
} else {
    if (Test-PortInUse) {
        Stop-WithPause 1 "[ERROR] Port $AppPort is already in use, but it is not DateTimeChecker. Close the app using this port, then run again."
    }

    Write-Log '[INFO] Spring Boot app is not running. Starting it now...'
    Write-Log "[INFO] Spring Boot log: $AppLogFile"

    $startCommand = "set SERVER_PORT=$AppPort&& .\mvnw.cmd spring-boot:run > `"$AppLogFile`" 2>&1"
    Start-Process `
        -FilePath 'cmd.exe' `
        -ArgumentList '/c', $startCommand `
        -WorkingDirectory $ProjectDir `
        -WindowStyle Minimized

    Write-Log "[INFO] Waiting for DateTimeChecker API at $BaseUrl ..."

    $ready = $false
    for ($attempt = 1; $attempt -le 60; $attempt++) {
        Start-Sleep -Seconds 2
        Write-Log "[INFO] Readiness check attempt $attempt/60..."
        if (Test-DateTimeCheckerApi) {
            $ready = $true
            break
        }
    }

    if (-not $ready) {
        Stop-WithPause 1 "[ERROR] Spring Boot app did not become ready after 120 seconds. Check: $AppLogFile"
    }
}

Write-Log '[INFO] DateTimeChecker API is ready.'
Write-Log ''
Write-Log '[INFO] Running k6 load test...'
Write-Log "[INFO] Test data: $(Join-Path $TopicDir 'test-data.json')"
Write-Log "[INFO] k6 script: $(Join-Path $TopicDir 'load-test.js')"
Write-Log "[INFO] Target: $BaseUrl/api/datetime/check"
Write-Log "[INFO] Demo mode: $DemoMode (about 15 seconds, ramping 5 -> 15 -> 0 VUs)"
Write-Log '[INFO] Criteria: p95 response time < 500ms, HTTP failures < 1%, checks > 99%'
Write-Log "[INFO] k6 console log: $K6ConsoleLog"
Write-Log "[INFO] k6 JSON summary: $K6SummaryFile"
Write-Log ''

$k6Args = @(
    'run',
    '-e', "BASE_URL=$BaseUrl",
    '-e', "DEMO_MODE=$DemoMode",
    '--summary-export', $K6SummaryFile,
    (Join-Path $TopicDir 'load-test.js')
)

Push-Location $TopicDir
try {
    & k6 @k6Args 2>&1 | Tee-Object -FilePath $K6ConsoleLog
    $k6Exit = $LASTEXITCODE
} finally {
    Pop-Location
}

Get-Content $K6ConsoleLog | Add-Content -Path $LogFile
Write-Log ''

if ($k6Exit -eq 0) {
    Write-Log '[SUCCESS] k6 performance test passed.'
} else {
    Write-Log '[FAILED] k6 performance test failed. Check the k6 summary above.'
}

if (Test-Path $K6SummaryFile) {
    $summary = Get-Content -Raw $K6SummaryFile | ConvertFrom-Json
    $duration = $summary.metrics.http_req_duration
    $failed = $summary.metrics.http_req_failed
    $checks = $summary.metrics.checks
    $requests = $summary.metrics.http_reqs
    $vusMax = $summary.metrics.vus_max

    Write-Log ''
    Write-Log '================ HUMAN READABLE RESULT SUMMARY ================'
    Write-Log ('Result: ' + $(if ($k6Exit -eq 0) { 'PASS' } else { 'FAIL' }))
    Write-Log "Target: $BaseUrl/api/datetime/check"
    Write-Log "Demo mode: $DemoMode"
    Write-Log "HTTP requests: $([int]$requests.count)"
    Write-Log ('HTTP failed rate: {0:P2}' -f [double]$failed.rate)
    Write-Log ('Checks passed rate: {0:P2}' -f [double]$checks.value)
    Write-Log "Checks passed: $([int]$checks.passes)"
    Write-Log "Checks failed: $([int]$checks.fails)"
    Write-Log ('Response avg: {0:N2} ms' -f [double]$duration.avg)
    Write-Log ('Response p95: {0:N2} ms' -f [double]$duration.'p(95)')
    Write-Log "Virtual users max: $([int]$vusMax.value)"
    Write-Log '==============================================================='
} else {
    Write-Log '[WARN] k6 did not create a JSON summary file.'
}

Write-Log ''
Write-Log '[INFO] Report files:'
Write-Log "[INFO] - Main log: $LogFile"
Write-Log "[INFO] - k6 console output: $K6ConsoleLog"
Write-Log "[INFO] - k6 JSON summary: $K6SummaryFile"
if (Test-Path $AppLogFile) {
    Write-Log "[INFO] - Spring Boot log: $AppLogFile"
}

Write-Log ''
Read-Host 'Press Enter to close'
exit $k6Exit
