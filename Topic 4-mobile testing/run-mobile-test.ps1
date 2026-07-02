param(
  [switch] $Demo
)

$ErrorActionPreference = 'Stop'

$topicDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = (Resolve-Path (Join-Path $topicDir '..')).Path
$configPath = Join-Path $topicDir 'playwright.mobile.config.js'
$demoConfigPath = Join-Path $topicDir 'playwright.mobile.demo.config.js'
$serverLog = Join-Path $topicDir 'mobile-test-server.log'
$serverErrorLog = Join-Path $topicDir 'mobile-test-server.err.log'
$serverProcess = $null
$preferredPort = 8080

function Invoke-Step {
  param(
    [string] $Title,
    [scriptblock] $Action
  )

  Write-Host ""
  Write-Host "==> $Title"
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "$Title failed with exit code $LASTEXITCODE."
  }
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
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/mobile/index.html" -TimeoutSec 2 | Out-Null
    return $true
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

try {
  Set-Location $rootDir

  if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    throw 'npm was not found. Please install Node.js first.'
  }

  if (-not (Test-Path -LiteralPath (Join-Path $rootDir 'node_modules\@playwright\test'))) {
    Invoke-Step 'Installing npm dependencies' {
      npm.cmd install
    }
  }

  if (Test-PlaywrightChromiumInstalled) {
    Write-Host ""
    Write-Host '==> Playwright Chromium browser is already installed'
  } else {
    Invoke-Step 'Installing Playwright Chromium browser' {
      npx.cmd playwright install chromium
    }
  }

  $serverPort = Get-FreePort -PreferredPort $preferredPort
  $baseUrl = "http://localhost:$serverPort"
  Write-Host ""
  Write-Host "==> Using mobile test URL: $baseUrl/mobile/index.html"

  if (-not (Test-AppReady -BaseUrl $baseUrl)) {
    Write-Host ""
    Write-Host "==> Starting Spring Boot server on port $serverPort"
    Remove-Item -LiteralPath $serverLog, $serverErrorLog -ErrorAction SilentlyContinue
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $env:ComSpec
    $processInfo.Arguments = "/d /c call mvnw.cmd -Dspring-boot.run.arguments=--server.port=$serverPort spring-boot:run > `"$serverLog`" 2> `"$serverErrorLog`""
    $processInfo.WorkingDirectory = $rootDir
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $serverProcess = [System.Diagnostics.Process]::Start($processInfo)

    $ready = $false
    for ($i = 1; $i -le 60; $i++) {
      Start-Sleep -Seconds 2
      if (Test-AppReady -BaseUrl $baseUrl) {
        $ready = $true
        break
      }
      if ($serverProcess.HasExited) {
        throw "Spring Boot stopped before becoming ready. See $serverLog and $serverErrorLog."
      }
      Write-Host "Waiting for app... ($i/60)"
    }

    if (-not $ready) {
      throw "Spring Boot did not become ready in time. See $serverLog and $serverErrorLog."
    }
  } else {
    Write-Host ""
    Write-Host "==> Spring Boot server is already running on $baseUrl"
  }

  if ($Demo) {
    Invoke-Step 'Running visible mobile phone demo' {
      $env:BASE_URL = $baseUrl
      npx.cmd playwright test --config "$demoConfigPath" --project 'iPhone 14 Pro Max Demo' -g 'Phone demo' --workers=1
    }
  } else {
    Invoke-Step 'Running mobile Playwright tests' {
      $env:BASE_URL = $baseUrl
      npx.cmd playwright test --config "$configPath" --project 'iPhone 14 Pro Max' --grep-invert 'Demo canvas'
    }
  }
} finally {
  if ($serverProcess -and -not $serverProcess.HasExited) {
    Write-Host ""
    Write-Host '==> Stopping Spring Boot server started by this script'
    taskkill.exe /PID $serverProcess.Id /T /F | Out-Null
  }
}
