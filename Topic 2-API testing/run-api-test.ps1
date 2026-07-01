$ErrorActionPreference = 'Stop'

$TopicDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Resolve-Path (Join-Path $TopicDir '..')
$AppPort = 8080
$BaseUrl = "http://localhost:$AppPort"
$RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportDir = Join-Path $TopicDir "reports\run-$RunId"
$LogFile = Join-Path $ReportDir 'run.log'
$NewmanConsoleLog = Join-Path $ReportDir 'newman-console.log'
$NewmanJsonFile = Join-Path $ReportDir 'newman-summary.json'
$AppLogFile = Join-Path $ReportDir 'spring-boot.log'
$CollectionFile = Join-Path $TopicDir 'DateTimeChecker API.postman_collection.json'
$TestDataFile = Join-Path $ProjectDir 'test-data.json'

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
Write-Log 'Topic 2 - API Testing Demo with Postman/Newman'
Write-Log 'Project: DateTimeChecker'
Write-Log "Run ID: run-$RunId"
Write-Log "Report folder: $ReportDir"
Write-Log "Target API: $BaseUrl/api/datetime/check"
Write-Log '============================================================'
Write-Log ''

if (-not (Test-Path $CollectionFile)) {
    Stop-WithPause 1 "[ERROR] Cannot find Postman collection: $CollectionFile"
}

if (-not (Test-Path $TestDataFile)) {
    Stop-WithPause 1 "[ERROR] Cannot find test data file: $TestDataFile"
}

$javaPath = Get-Command java -ErrorAction SilentlyContinue
if (-not $javaPath) {
    Stop-WithPause 1 '[ERROR] Java is not installed or not available in PATH.'
}

$newmanPath = Get-Command newman -ErrorAction SilentlyContinue
$npxPath = Get-Command npx -ErrorAction SilentlyContinue
if (-not $newmanPath -and -not $npxPath) {
    Stop-WithPause 1 '[ERROR] Newman is not installed. Install Node.js, then run: npm install -g newman'
}

Write-Log '[INFO] Environment information'
Write-Log "[INFO] Java path: $($javaPath.Source)"
if ($newmanPath) {
    Write-Log "[INFO] Newman path: $($newmanPath.Source)"
} else {
    Write-Log "[INFO] Newman was not found globally. The script will use npx newman."
}
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
Write-Log '[INFO] Running Postman collection with Newman...'
Write-Log "[INFO] Collection: $CollectionFile"
Write-Log "[INFO] Test data: $TestDataFile"
Write-Log "[INFO] Base URL: $BaseUrl"
Write-Log "[INFO] Newman console log: $NewmanConsoleLog"
Write-Log "[INFO] Newman JSON summary: $NewmanJsonFile"
Write-Log ''

$newmanArgs = @(
    'run',
    $CollectionFile,
    '--iteration-data', $TestDataFile,
    '--env-var', "baseUrl=$BaseUrl",
    '--reporters', 'cli,json',
    '--reporter-json-export', $NewmanJsonFile
)

Push-Location $ProjectDir
try {
    if ($newmanPath) {
        & newman @newmanArgs 2>&1 | Tee-Object -FilePath $NewmanConsoleLog
        $newmanExit = $LASTEXITCODE
    } else {
        & npx --yes newman @newmanArgs 2>&1 | Tee-Object -FilePath $NewmanConsoleLog
        $newmanExit = $LASTEXITCODE
    }
} finally {
    Pop-Location
}

Get-Content $NewmanConsoleLog | Add-Content -Path $LogFile
Write-Log ''

if ($newmanExit -eq 0) {
    Write-Log '[SUCCESS] API testing passed.'
} else {
    Write-Log '[FAILED] API testing failed. Check the Newman output above.'
}

if (Test-Path $NewmanJsonFile) {
    $summary = Get-Content -Raw $NewmanJsonFile | ConvertFrom-Json
    $stats = $summary.run.stats

    Write-Log ''
    Write-Log '================ HUMAN READABLE RESULT SUMMARY ================'
    Write-Log ('Result: ' + $(if ($newmanExit -eq 0) { 'PASS' } else { 'FAIL' }))
    Write-Log "Target: $BaseUrl/api/datetime/check"
    Write-Log "Iterations total: $($stats.iterations.total)"
    Write-Log "Iterations failed: $($stats.iterations.failed)"
    Write-Log "Requests total: $($stats.requests.total)"
    Write-Log "Requests failed: $($stats.requests.failed)"
    Write-Log "Assertions total: $($stats.assertions.total)"
    Write-Log "Assertions failed: $($stats.assertions.failed)"
    Write-Log '==============================================================='
} else {
    Write-Log '[WARN] Newman did not create a JSON summary file.'
}

Write-Log ''
Write-Log '[INFO] Report files:'
Write-Log "[INFO] - Main log: $LogFile"
Write-Log "[INFO] - Newman console output: $NewmanConsoleLog"
Write-Log "[INFO] - Newman JSON summary: $NewmanJsonFile"
if (Test-Path $AppLogFile) {
    Write-Log "[INFO] - Spring Boot log: $AppLogFile"
}

Write-Log ''
Read-Host 'Press Enter to close'
exit $newmanExit

