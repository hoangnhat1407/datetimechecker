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
$SourceStaticDir = Join-Path $ProjectDir 'src\main\resources\static'
$ClassStaticDir = Join-Path $ProjectDir 'target\classes\static'
$JarPath = Join-Path $ProjectDir 'target\datetimechecker-0.0.1-SNAPSHOT.jar'
$PreferredPort = 18080
$ExpectedBaselineFiles = @(
  'home-empty.png',
  'valid-date-result.png',
  'invalid-date-result.png'
)
$ServerProcess = $null
$ExitCode = 0

New-Item -ItemType Directory -Force -Path $BaselineDir, $CurrentDir, $DiffDir, $RunReportDir, $TestResultsDir | Out-Null

function Add-RunLogLine {
  param([string] $Message = '')

  for ($attempt = 1; $attempt -le 5; $attempt++) {
    try {
      Add-Content -LiteralPath $RunLog -Value $Message -ErrorAction Stop
      return
    } catch [System.IO.IOException] {
      Start-Sleep -Milliseconds 100
    }
  }
}

function Write-Log {
  param([string] $Message = '')
  Write-Host $Message
  Add-RunLogLine $Message
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
    [string[]] $Arguments,
    [switch] $QuietConsole
  )

  Write-Log ''
  Write-Log "==> $Title"
  & $FilePath @Arguments 2>&1 | ForEach-Object {
    $line = $_.ToString()
    if (-not $QuietConsole) {
      Write-Host $line
    }
    Add-RunLogLine $line
  }
  $commandExitCode = $LASTEXITCODE
  if ($QuietConsole) {
    Write-Log "[INFO] $Title finished with exit code $commandExitCode. Full output is saved in: $RunLog"
  }
  return $commandExitCode
}

function Copy-FailureImages {
  $runDiffDir = Join-Path $DiffDir "run-$RunId"
  $images = Get-ChildItem -LiteralPath $TestResultsDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -like '*-actual.png' -or
      $_.Name -like '*-expected.png' -or
      $_.Name -like '*-diff.png'
    }

  if (-not $images) {
    return 0
  }

  New-Item -ItemType Directory -Force -Path $runDiffDir | Out-Null
  foreach ($image in $images) {
    $safeParent = $image.Directory.Name -replace '[^a-zA-Z0-9_.-]', '_'
    $destination = Join-Path $runDiffDir "$safeParent-$($image.Name)"
    Copy-Item -LiteralPath $image.FullName -Destination $destination -Force
  }
  Write-Log "[INFO] Failure comparison images copied to: $runDiffDir"
  return @($images).Count
}

function Get-DiffSummary {
  $runDiffDir = Join-Path $DiffDir "run-$RunId"
  $diffFiles = Get-ChildItem -LiteralPath $runDiffDir -File -Filter '*-diff.png' -ErrorAction SilentlyContinue
  if (-not $diffFiles) {
    return @()
  }

  $summary = New-Object System.Collections.Generic.List[string]
  foreach ($snapshotName in $ExpectedBaselineFiles) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($snapshotName)
    $matched = $diffFiles | Where-Object { $_.Name -like "*$baseName-diff.png" } | Select-Object -First 1
    if ($matched) {
      $summary.Add($snapshotName)
    }
  }

  return $summary.ToArray()
}

function Start-DateTimeCheckerServer {
  param([int] $Port)

  $processInfo = New-Object System.Diagnostics.ProcessStartInfo
  if (Test-Path -LiteralPath $JarPath) {
    Write-Log "[INFO] Using Spring Boot jar: $JarPath"
    $processInfo.FileName = 'java.exe'
    $processInfo.Arguments = "-Dserver.port=$Port -jar `"$JarPath`""
  } else {
    Write-Log '[INFO] No built jar found. Falling back to Maven spring-boot:run.'
    $processInfo.FileName = $env:ComSpec
    $processInfo.Arguments = "/d /c call mvnw.cmd -Dspring-boot.run.arguments=--server.port=$Port spring-boot:run"
  }

  $processInfo.WorkingDirectory = $ProjectDir
  $processInfo.RedirectStandardOutput = $true
  $processInfo.RedirectStandardError = $true
  $processInfo.UseShellExecute = $false
  $processInfo.CreateNoWindow = $true
  $script:ServerProcess = [System.Diagnostics.Process]::Start($processInfo)
  $script:ServerProcess.BeginOutputReadLine()
  $script:ServerProcess.BeginErrorReadLine()
  Register-ObjectEvent -InputObject $script:ServerProcess -EventName OutputDataReceived -Action {
    if ($EventArgs.Data) {
      Add-Content -LiteralPath $Event.MessageData.LogFile -Value $EventArgs.Data
    }
  } -MessageData @{ LogFile = $ServerLog } | Out-Null
  Register-ObjectEvent -InputObject $script:ServerProcess -EventName ErrorDataReceived -Action {
    if ($EventArgs.Data) {
      Add-Content -LiteralPath $Event.MessageData.LogFile -Value $EventArgs.Data
    }
  } -MessageData @{ LogFile = $ServerErrorLog } | Out-Null
}

function Stop-DateTimeCheckerServer {
  if ($script:ServerProcess -and -not $script:ServerProcess.HasExited) {
    Write-Log ''
    Write-Log '==> Stopping Spring Boot server started by this script'
    taskkill.exe /PID $script:ServerProcess.Id /T /F | Out-Null
  }
  $script:ServerProcess = $null
}

function Wait-ForAppReady {
  param([string] $BaseUrl)

  $ready = $false
  for ($i = 1; $i -le 60; $i++) {
    Start-Sleep -Seconds 2
    if (Test-AppReady -BaseUrl $BaseUrl) {
      $ready = $true
      break
    }
    if ($ServerProcess -and $ServerProcess.HasExited) {
      Stop-WithError "Spring Boot stopped before becoming ready. Check $ServerLog and $ServerErrorLog."
    }
    Write-Log "Waiting for app... ($i/60)"
  }

  if (-not $ready) {
    Stop-WithError "Spring Boot did not become ready in time. Check $ServerLog and $ServerErrorLog."
  }
}

function Sync-StaticResourcesToRuntime {
  if (-not (Test-Path -LiteralPath $SourceStaticDir)) {
    Stop-WithError "Cannot find static source folder: $SourceStaticDir"
  }

  Write-Log ''
  Write-Log '==> Syncing current static files to runtime'
  New-Item -ItemType Directory -Force -Path $ClassStaticDir | Out-Null
  Copy-Item -Path (Join-Path $SourceStaticDir '*') -Destination $ClassStaticDir -Recurse -Force

  if (-not (Test-Path -LiteralPath $JarPath)) {
    return
  }

  Write-Log '==> Updating current static files inside Spring Boot jar'
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::Open($JarPath, [System.IO.Compression.ZipArchiveMode]::Update)
  try {
    $staticFiles = Get-ChildItem -LiteralPath $SourceStaticDir -Recurse -File
    foreach ($file in $staticFiles) {
      $relativePath = $file.FullName.Substring($SourceStaticDir.Length).TrimStart('\', '/')
      $entryName = 'BOOT-INF/classes/static/' + ($relativePath -replace '\\', '/')
      $existingEntry = $zip.GetEntry($entryName)
      if ($existingEntry) {
        $existingEntry.Delete()
      }
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName) | Out-Null
    }
  } finally {
    $zip.Dispose()
  }
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

  Sync-StaticResourcesToRuntime

  $missingBaselineFiles = @(
    $ExpectedBaselineFiles | Where-Object {
      -not (Test-Path -LiteralPath (Join-Path $BaselineDir $_))
    }
  )
  $updateBaseline = $args.Count -gt 0 -and $args[0] -in @('update', '--update', '/update')

  if ($missingBaselineFiles.Count -gt 0 -or $updateBaseline) {
    Write-Log ''
    Write-Log '==> Starting normal app to prepare baseline screenshots'
    Start-DateTimeCheckerServer -Port $ServerPort
    Wait-ForAppReady -BaseUrl $BaseUrl

    if ($updateBaseline) {
      Write-Log ''
      Write-Log '==> Updating visual baseline images from normal UI'
    } else {
      Write-Log ''
      Write-Log '==> Missing baseline images. Creating required baseline images from normal UI'
      foreach ($missingFile in $missingBaselineFiles) {
        Write-Log "[INFO] Missing baseline: $missingFile"
      }
    }

    $baselineCode = Invoke-LoggedCommand 'Creating baseline screenshots' 'npx.cmd' @(
      'playwright', 'test',
      '--config', $ConfigPath,
      '--update-snapshots'
    )
    if ($baselineCode -ne 0) {
      Stop-WithError "Baseline creation failed with exit code $baselineCode."
    }

    Stop-DateTimeCheckerServer
  }

  Write-Log ''
  Write-Log '==> Starting app with current code'
  Start-DateTimeCheckerServer -Port $ServerPort
  Wait-ForAppReady -BaseUrl $BaseUrl

  $testCode = Invoke-LoggedCommand 'Running visual regression comparison' 'npx.cmd' @(
    'playwright', 'test',
    '--config', $ConfigPath,
    '--reporter=line'
  ) -QuietConsole
  $diffImageCount = Copy-FailureImages
  $diffSnapshots = Get-DiffSummary

  Write-Log ''
  if ($testCode -ne 0 -and $diffImageCount -gt 0) {
    Write-Log '[DIFFERENCES FOUND] Visual differences were detected and copied to the diff folder.'
    if ($diffSnapshots.Count -gt 0) {
      Write-Log '[SUMMARY] Different screenshots:'
      foreach ($snapshot in $diffSnapshots) {
        Write-Log "[SUMMARY] - $snapshot"
      }
    }
    $ExitCode = 0
  } elseif ($testCode -eq 0) {
    Write-Log '[SUCCESS] No visual differences were detected.'
    $ExitCode = 0
  } else {
    Write-Log '[FAILED] Visual regression failed, but no diff images were found. Check the Playwright report.'
    $ExitCode = $testCode
  }

  Write-Log ''
  Write-Log '[INFO] Image folders:'
  Write-Log "[INFO] - Before/baseline: $BaselineDir"
  Write-Log "[INFO] - After/current:   $CurrentDir"
  Write-Log "[INFO] - Diff failures:   $DiffDir"
  Write-Log "[INFO] - Run report:      $RunReportDir"
  Write-Log "[INFO] - Full command log: $RunLog"
} catch {
  if ($ExitCode -eq 0) {
    $ExitCode = 1
  }
  Write-Log ''
  Write-Log "[ERROR] $($_.Exception.Message)"
} finally {
  Stop-DateTimeCheckerServer

  Write-Log ''
  Write-Log "Finished with exit code $ExitCode"
  Write-Log "Main log: $RunLog"
  if (-not $env:CI) {
    Read-Host 'Press Enter to close'
  }
  exit $ExitCode
}
