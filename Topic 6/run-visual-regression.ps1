$ErrorActionPreference = 'Stop'

$TopicDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = (Resolve-Path (Join-Path $TopicDir '..')).Path
$ConfigPath = Join-Path $TopicDir 'playwright.visual.config.js'
$ArtifactDir = Join-Path $TopicDir 'visual-artifacts'
$BaselineDir = Join-Path $ArtifactDir 'baseline'
$CurrentDir = Join-Path $ArtifactDir 'current'
$DiffDir = Join-Path $ArtifactDir 'diff'
$ReportsDir = Join-Path $ArtifactDir 'reports'
$RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$RunReportDir = Join-Path $ReportsDir "run-$RunId"
$TestResultsDir = Join-Path $RunReportDir 'test-results'
$HtmlReportDir = Join-Path $RunReportDir 'playwright-report'
$ServerLog = Join-Path $RunReportDir 'spring-boot.log'
$ServerErrorLog = Join-Path $RunReportDir 'spring-boot.err.log'
$RunLog = Join-Path $RunReportDir 'run.log'
$JarPath = Join-Path $ProjectDir 'target\datetimechecker-0.0.1-SNAPSHOT.jar'
$PreferredPort = 18080
$ServerProcess = $null
$ExitCode = 0

New-Item -ItemType Directory -Force -Path $BaselineDir, $CurrentDir, $DiffDir, $RunReportDir, $TestResultsDir | Out-Null

function Write-Log {
  param([string] $Message = '')
  $Message | Tee-Object -FilePath $RunLog -Append
}

function Stop-WithError {
  param([string] $Message)
  Write-Log "[ERROR] $Message"
  $script:ExitCode = 1
  throw $Message
}

function Test-PortAvailable {
  param([int] $Port)

  $listener = $null
  try {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
    $listener.Start()
    return $true
  } catch {
    return $false
  } finally {
    if ($listener) {
      $listener.Stop()
    }
  }
}

function Get-FreePort {
  param([int] $PreferredPort)

  for ($port = $PreferredPort; $port -le ($PreferredPort + 50); $port++) {
    if (Test-PortAvailable -Port $port) {
      return $port
    }
  }

  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
  $listener.Start()
  try {
    return $listener.LocalEndpoint.Port
  } finally {
    $listener.Stop()
  }
}

function Test-AppReady {
  param([string] $BaseUrl)

  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/" -TimeoutSec 2
    return $response.StatusCode -ge 200 -and $response.StatusCode -lt 500
  } catch {
    return $false
  }
}

function Test-PlaywrightChromiumInstalled {
  $cacheRoots = @()
  if ($env:PLAYWRIGHT_BROWSERS_PATH) {
    $cacheRoots += $env:PLAYWRIGHT_BROWSERS_PATH
  }
  if ($env:LOCALAPPDATA) {
    $cacheRoots += (Join-Path $env:LOCALAPPDATA 'ms-playwright')
  }

  foreach ($cacheRoot in $cacheRoots) {
    if (Test-Path -LiteralPath $cacheRoot) {
      $chromium = Get-ChildItem -LiteralPath $cacheRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'chromium-*' -or $_.Name -like 'chromium_headless_shell-*' } |
        Select-Object -First 1
      if ($chromium) {
        return $true
      }
    }
  }

  return $false
}

function Invoke-LoggedCommand {
  param(
    [string] $Title,
    [string] $FilePath,
    [string[]] $Arguments
  )

  Write-Log ''
  Write-Log "==> $Title"
  & $FilePath @Arguments 2>&1 | Tee-Object -FilePath $RunLog -Append
  return $LASTEXITCODE
}

function Copy-FailureImages {
  $runDiffDir = Join-Path $DiffDir "run-$RunId"
  $images = Get-ChildItem -LiteralPath $TestResultsDir -Recurse -File -Include '*-actual.png', '*-expected.png', '*-diff.png' -ErrorAction SilentlyContinue
  if (-not $images) {
    return
  }

  New-Item -ItemType Directory -Force -Path $runDiffDir | Out-Null
  foreach ($image in $images) {
    $safeParent = $image.Directory.Name -replace '[^a-zA-Z0-9_.-]', '_'
    $destination = Join-Path $runDiffDir "$safeParent-$($image.Name)"
    Copy-Item -LiteralPath $image.FullName -Destination $destination -Force
  }
  Write-Log "[INFO] Failure comparison images copied to: $runDiffDir"
}

try {
  Set-Location $ProjectDir

  Write-Log '============================================================'
  Write-Log 'Topic 6 - Visual Regression Testing'
  Write-Log 'Project: DateTimeChecker'
  Write-Log "Run ID: run-$RunId"
  Write-Log "Topic folder: $TopicDir"
  Write-Log "Baseline images: $BaselineDir"
  Write-Log "Current images: $CurrentDir"
  Write-Log "Run report: $RunReportDir"
  Write-Log '============================================================'

  if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    Stop-WithError 'npm was not found. Install Node.js first.'
  }

  if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Stop-WithError 'Java was not found. Install Java 17 or make sure java is available in PATH.'
  }

  if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir 'node_modules\@playwright\test'))) {
    $installCode = Invoke-LoggedCommand 'Installing npm dependencies' 'npm.cmd' @('install')
    if ($installCode -ne 0) {
      Stop-WithError "npm install failed with exit code $installCode."
    }
  }

  if (-not (Test-PlaywrightChromiumInstalled)) {
    $browserCode = Invoke-LoggedCommand 'Installing Playwright Chromium browser' 'npx.cmd' @('playwright', 'install', 'chromium')
    if ($browserCode -ne 0) {
      Stop-WithError "Playwright Chromium install failed with exit code $browserCode."
    }
  } else {
    Write-Log ''
    Write-Log '==> Playwright Chromium browser is already installed'
  }

  $ServerPort = Get-FreePort -PreferredPort $PreferredPort
  $BaseUrl = "http://localhost:$ServerPort"
  $env:BASE_URL = $BaseUrl
  $env:VISUAL_CURRENT_DIR = $CurrentDir
  $env:VISUAL_TEST_RESULTS_DIR = $TestResultsDir
  $env:VISUAL_HTML_REPORT_DIR = $HtmlReportDir

  Write-Log ''
  Write-Log "==> Using visual test URL: $BaseUrl/"

  if (-not (Test-AppReady -BaseUrl $BaseUrl)) {
    Write-Log ''
    Write-Log "==> Starting Spring Boot server on port $ServerPort"
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    if (Test-Path -LiteralPath $JarPath) {
      Write-Log "[INFO] Using existing Spring Boot jar: $JarPath"
      $processInfo.FileName = 'java.exe'
      $processInfo.Arguments = "-Dserver.port=$ServerPort -jar `"$JarPath`""
    } else {
      Write-Log '[INFO] No built jar found. Falling back to Maven spring-boot:run.'
      $processInfo.FileName = $env:ComSpec
      $processInfo.Arguments = "/d /c call mvnw.cmd -Dspring-boot.run.arguments=--server.port=$ServerPort spring-boot:run"
    }
    $processInfo.WorkingDirectory = $ProjectDir
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $ServerProcess = [System.Diagnostics.Process]::Start($processInfo)
    $ServerProcess.BeginOutputReadLine()
    $ServerProcess.BeginErrorReadLine()
    Register-ObjectEvent -InputObject $ServerProcess -EventName OutputDataReceived -Action {
      if ($EventArgs.Data) {
        Add-Content -LiteralPath $Event.MessageData.LogFile -Value $EventArgs.Data
      }
    } -MessageData @{ LogFile = $ServerLog } | Out-Null
    Register-ObjectEvent -InputObject $ServerProcess -EventName ErrorDataReceived -Action {
      if ($EventArgs.Data) {
        Add-Content -LiteralPath $Event.MessageData.LogFile -Value $EventArgs.Data
      }
    } -MessageData @{ LogFile = $ServerErrorLog } | Out-Null

    $ready = $false
    for ($i = 1; $i -le 60; $i++) {
      Start-Sleep -Seconds 2
      if (Test-AppReady -BaseUrl $BaseUrl) {
        $ready = $true
        break
      }
      if ($ServerProcess.HasExited) {
        Stop-WithError "Spring Boot stopped before becoming ready. Check $ServerLog and $ServerErrorLog."
      }
      Write-Log "Waiting for app... ($i/60)"
    }

    if (-not $ready) {
      Stop-WithError "Spring Boot did not become ready in time. Check $ServerLog and $ServerErrorLog."
    }
  }

  $baselineExists = Get-ChildItem -LiteralPath $BaselineDir -Recurse -File -Filter '*.png' -ErrorAction SilentlyContinue | Select-Object -First 1
  $updateBaseline = $args.Count -gt 0 -and $args[0] -in @('update', '--update', '/update')

  if (-not $baselineExists -or $updateBaseline) {
    if ($updateBaseline) {
      Write-Log ''
      Write-Log '==> Updating visual baseline images'
    } else {
      Write-Log ''
      Write-Log '==> No baseline images found. Creating first baseline images'
    }

    $baselineCode = Invoke-LoggedCommand 'Creating baseline screenshots' 'npx.cmd' @(
      'playwright', 'test',
      '--config', $ConfigPath,
      '--update-snapshots'
    )
    if ($baselineCode -ne 0) {
      Stop-WithError "Baseline creation failed with exit code $baselineCode."
    }
  }

  $testCode = Invoke-LoggedCommand 'Running visual regression comparison' 'npx.cmd' @(
    'playwright', 'test',
    '--config', $ConfigPath
  )
  $ExitCode = $testCode
  Copy-FailureImages

  Write-Log ''
  if ($ExitCode -eq 0) {
    Write-Log '[SUCCESS] Visual regression testing passed.'
  } else {
    Write-Log '[FAILED] Visual regression testing found UI differences or test failures.'
  }

  Write-Log ''
  Write-Log '[INFO] Image folders:'
  Write-Log "[INFO] - Before/baseline: $BaselineDir"
  Write-Log "[INFO] - After/current:   $CurrentDir"
  Write-Log "[INFO] - Diff failures:   $DiffDir"
  Write-Log "[INFO] - Run report:      $RunReportDir"
} catch {
  if ($ExitCode -eq 0) {
    $ExitCode = 1
  }
  Write-Log ''
  Write-Log "[ERROR] $($_.Exception.Message)"
} finally {
  if ($ServerProcess -and -not $ServerProcess.HasExited) {
    Write-Log ''
    Write-Log '==> Stopping Spring Boot server started by this script'
    taskkill.exe /PID $ServerProcess.Id /T /F | Out-Null
  }

  Write-Log ''
  Write-Log "Finished with exit code $ExitCode"
  Write-Log "Main log: $RunLog"
  if (-not $env:CI) {
    Read-Host 'Press Enter to close'
  }
  exit $ExitCode
}
