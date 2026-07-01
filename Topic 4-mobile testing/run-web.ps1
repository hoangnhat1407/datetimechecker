$ErrorActionPreference = 'Stop'

$topicDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = (Resolve-Path (Join-Path $topicDir '..')).Path
$serverLog = Join-Path $topicDir 'mobile-web-server.log'
$serverErrorLog = Join-Path $topicDir 'mobile-web-server.err.log'
$preferredPort = 8080

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

Set-Location $rootDir

$serverPort = Get-FreePort -PreferredPort $preferredPort
$baseUrl = "http://localhost:$serverPort"
$mobileUrl = "$baseUrl/mobile/index.html"

Write-Host "Starting Spring Boot on port $serverPort"
Write-Host "Mobile web URL: $mobileUrl"
Write-Host "Logs:"
Write-Host "  $serverLog"
Write-Host "  $serverErrorLog"
Write-Host ""

Remove-Item -LiteralPath $serverLog, $serverErrorLog -ErrorAction SilentlyContinue

$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = $env:ComSpec
$processInfo.Arguments = "/d /c call mvnw.cmd -Dspring-boot.run.arguments=--server.port=$serverPort spring-boot:run > `"$serverLog`" 2> `"$serverErrorLog`""
$processInfo.WorkingDirectory = $rootDir
$processInfo.UseShellExecute = $false
$processInfo.CreateNoWindow = $true
$serverProcess = [System.Diagnostics.Process]::Start($processInfo)

try {
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

  Write-Host ""
  Write-Host "App is ready: $mobileUrl"
  Start-Process $mobileUrl
  Write-Host ""
  Write-Host "Keep this window open while using the web app."
  Write-Host "Press Enter here to stop the server."
  Read-Host | Out-Null
} finally {
  if ($serverProcess -and -not $serverProcess.HasExited) {
    Write-Host "Stopping Spring Boot server..."
    taskkill.exe /PID $serverProcess.Id /T /F | Out-Null
  }
}
